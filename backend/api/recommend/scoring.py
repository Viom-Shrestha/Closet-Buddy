from typing import Dict, Iterable, List, Optional, Tuple

from ..models import ClothingItem
from . import clip_utils
from .filters import (
    COLD_SIGNALS,
    RAIN_SIGNALS,
    SNOW_REQUIRED,
    WARM_SIGNALS,
    attr_set,
    is_outerwear,
    normalize_occasion,
)


def _clamp(value: float, min_value: float = 0.0, max_value: float = 1.0) -> float:
    return max(min(value, max_value), min_value)


def build_prompt(user_prompt: Optional[str], occasion: Optional[str], weather: Dict) -> str:
    temperature = (weather.get("temperature") or "").strip()
    condition = (weather.get("weather") or "").strip()

    parts: List[str] = []
    if user_prompt:
        parts.append(user_prompt.strip())
        if occasion:
            parts.append(occasion.strip())
        if temperature:
            parts.append(temperature)
        if condition:
            parts.append(condition)
        return " ".join([p for p in parts if p])

    weather_phrase = temperature or condition or "mild"
    if occasion:
        return f"a stylish {occasion.strip()} outfit for {weather_phrase} weather"
    return f"a stylish outfit for {weather_phrase} weather"


def _item_weather_score(
    item: ClothingItem,
    temperature: str,
    condition: str,
) -> float:
    attrs = attr_set(item)
    score = 0.5

    if temperature in {"freezing", "cold"}:
        if attrs & COLD_SIGNALS:
            score += 0.3
        if attrs & WARM_SIGNALS:
            score -= 0.3
        if is_outerwear(item):
            score += 0.1

    elif temperature in {"warm", "hot"}:
        if attrs & WARM_SIGNALS:
            score += 0.3
        if attrs & COLD_SIGNALS:
            score -= 0.3
        if is_outerwear(item):
            score -= 0.2

    elif temperature == "cool":
        if attrs & COLD_SIGNALS:
            score += 0.1
        if attrs & WARM_SIGNALS:
            score += 0.05

    if condition == "snowy":
        if attrs & SNOW_REQUIRED:
            score += 0.2
        elif attrs:
            score -= 0.2
        else:
            score -= 0.1

    if condition == "rainy":
        if attrs & RAIN_SIGNALS:
            score += 0.1
        elif attrs:
            score -= 0.05

    return _clamp(score)


def weather_score(outfit: Dict, weather: Dict) -> float:
    temperature = (weather.get("temperature") or "").strip().lower()
    condition = (weather.get("weather") or "").strip().lower()
    items = [outfit["topwear"], outfit["bottomwear"], outfit["shoes"]]
    if outfit.get("outerwear"):
        items.append(outfit["outerwear"])
    scores = [_item_weather_score(item, temperature, condition) for item in items]
    return sum(scores) / max(len(scores), 1)


def occasion_score(outfit: Dict, occasion: Optional[str]) -> float:
    if not occasion:
        return 0.5
    target = normalize_occasion(occasion)
    items = [outfit["topwear"], outfit["bottomwear"], outfit["shoes"]]
    if outfit.get("outerwear"):
        items.append(outfit["outerwear"])

    matches = 0
    for item in items:
        item_occ = normalize_occasion(item.occasion)
        attrs = attr_set(item)
        attrs = {normalize_occasion(attr) for attr in attrs}
        if item_occ == target or target in attrs:
            matches += 1
    return matches / max(len(items), 1)


def color_harmony_score(outfit: Dict) -> float:
    neutral = {"black", "white", "gray", "grey", "beige", "tan", "cream", "navy"}
    colors: List[str] = []
    items = [outfit["topwear"], outfit["bottomwear"], outfit["shoes"]]
    if outfit.get("outerwear"):
        items.append(outfit["outerwear"])

    for item in items:
        if item.dominant_color:
            colors.append(str(item.dominant_color).strip().lower())
        if item.secondary_color:
            colors.append(str(item.secondary_color).strip().lower())

    colors = [c for c in colors if c and c != "unknown"]
    if not colors:
        return 0.5

    unique = list(dict.fromkeys(colors))
    non_neutral = [c for c in unique if c not in neutral]

    score = 1.0
    if len(unique) > 3:
        score -= 0.2
    elif len(unique) > 2:
        score -= 0.1

    if len(non_neutral) > 2:
        score -= 0.2
    elif len(non_neutral) > 1:
        score -= 0.1

    return _clamp(score)


def layering_score(outfit: Dict, weather: Dict) -> float:
    temperature = (weather.get("temperature") or "").strip().lower()
    has_outer = outfit.get("outerwear") is not None

    if temperature in {"freezing", "cold"}:
        return 1.0 if has_outer else 0.0
    if temperature in {"warm", "hot"}:
        return 0.0 if has_outer else 1.0
    if temperature == "cool":
        return 0.7
    return 0.5


def clip_score(outfit: Dict, text_prompt: str) -> float:
    try:
        items = [outfit["topwear"], outfit["bottomwear"], outfit["shoes"]]
        if outfit.get("outerwear"):
            items.append(outfit["outerwear"])
        embeddings = [clip_utils.get_image_embedding(item.image.path) for item in items]
        outfit_embedding = clip_utils.average_embeddings(embeddings)
        text_embedding = clip_utils.get_text_embedding(text_prompt)
        return clip_utils.cosine_similarity(outfit_embedding, text_embedding)
    except Exception:
        # Keep recommendations available if model loading/inference fails.
        return 0.5


def final_score(outfit: Dict, weather: Dict, occasion: Optional[str], text_prompt: str) -> float:
    clip = clip_score(outfit, text_prompt)
    weather_fit = weather_score(outfit, weather)
    occasion_fit = occasion_score(outfit, occasion)
    color_fit = color_harmony_score(outfit)
    layering_fit = layering_score(outfit, weather)

    return (
        (0.5 * clip)
        + (0.2 * weather_fit)
        + (0.15 * occasion_fit)
        + (0.1 * color_fit)
        + (0.05 * layering_fit)
    )


def _ai_cohesion_reason(clip: float) -> str:
    if clip >= 0.8:
        return "The pieces feel cohesive and stylistically aligned."
    if clip >= 0.65:
        return "The outfit has decent cohesion with room for tighter styling."
    return "The outfit feels a bit mixed; the pieces do not fully align yet."


def _ai_color_reason(color: float) -> str:
    if color >= 0.85:
        return "Color harmony is strong, with a balanced palette."
    if color >= 0.7:
        return "Color pairing works reasonably well, though it could be cleaner."
    return "The color mix is busy; reducing contrast would improve balance."


def _ai_improvement_tip(clip: float, color: float, neutral_weather_fit: float, has_outerwear: bool) -> str:
    weakest = min(
        [
            ("cohesion", clip),
            ("color", color),
            ("weather", neutral_weather_fit),
        ],
        key=lambda item: item[1],
    )[0]

    if weakest == "cohesion":
        return "Try swapping one piece for a style that better matches the others."
    if weakest == "color":
        return "Limit the outfit to one dominant accent color with neutral support."
    if has_outerwear:
        return "Consider a lighter outer layer to keep the outfit more versatile."
    return "A light jacket option could make this outfit easier to adapt."


def ai_rating_snapshot(outfit: Dict) -> Dict:
    text_prompt = "a cohesive stylish everyday outfit"
    neutral_weather = {"temperature": "cool", "weather": "dry"}

    clip = clip_score(outfit, text_prompt)
    color = color_harmony_score(outfit)
    neutral_weather_fit = weather_score(outfit, neutral_weather)

    overall_raw = (0.60 * clip) + (0.25 * color) + (0.15 * neutral_weather_fit)
    score = round(1 + (4 * overall_raw), 1)
    score = max(1.0, min(5.0, score))

    reasons = [
        _ai_cohesion_reason(clip),
        _ai_color_reason(color),
        _ai_improvement_tip(clip, color, neutral_weather_fit, outfit.get("outerwear") is not None),
    ]

    return {
        "ai_rating_score": score,
        "ai_rating_reasons": reasons,
        "ai_rating_breakdown": {
            "clip": round(clip, 4),
            "color_harmony": round(color, 4),
            "neutral_weather_fit": round(neutral_weather_fit, 4),
            "overall_raw": round(overall_raw, 4),
        },
    }
