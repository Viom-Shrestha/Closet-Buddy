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
    target = occasion.strip().lower()
    items = [outfit["topwear"], outfit["bottomwear"], outfit["shoes"]]
    if outfit.get("outerwear"):
        items.append(outfit["outerwear"])

    matches = 0
    for item in items:
        item_occ = (item.occasion or "").strip().lower()
        attrs = attr_set(item)
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
    items = [outfit["topwear"], outfit["bottomwear"], outfit["shoes"]]
    if outfit.get("outerwear"):
        items.append(outfit["outerwear"])
    embeddings = [clip_utils.get_image_embedding(item.image.path) for item in items]
    outfit_embedding = clip_utils.average_embeddings(embeddings)
    text_embedding = clip_utils.get_text_embedding(text_prompt)
    return clip_utils.cosine_similarity(outfit_embedding, text_embedding)


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
