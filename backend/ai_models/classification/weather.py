from __future__ import annotations

from typing import Any, Dict, Iterable, List, Optional, Tuple

import clip
import torch
from PIL import Image

device = "cuda" if torch.cuda.is_available() else "cpu"
model, preprocess = clip.load("ViT-B/32", device=device)

# Prompt sets for temperature suitability.
TEMPERATURE_PROMPTS: Dict[str, List[str]] = {
    "freezing": [
        "heavy insulated winter parka for freezing weather",
        "thick puffer jacket for snow and extreme cold",
        "thermal outerwear for icy winter conditions",
    ],
    "cold": [
        "warm jacket and layered outfit for cold weather",
        "hoodie or sweater for chilly weather",
        "long sleeve warm clothing for winter day",
    ],
    "cool": [
        "light jacket and layered clothing for cool weather",
        "long sleeve casual outfit for mild weather",
        "transitional season clothing with light layers",
    ],
    "warm": [
        "breathable casual clothing for warm weather",
        "lightweight shirt for spring weather",
        "comfortable outfit for mild to warm day",
    ],
    "hot": [
        "very light t shirt outfit for hot summer weather",
        "sleeveless or short sleeve lightweight clothing for heat",
        "thin breathable summer top for high temperature",
    ],
}

# Prompt sets for weather conditions.
WEATHER_PROMPTS: Dict[str, List[str]] = {
    "rainy": [
        "waterproof rain jacket for rainy weather",
        "water resistant shell for wet conditions",
        "rain ready protective outerwear",
    ],
    "snowy": [
        "snow jacket with insulated winter protection",
        "heavy winter outerwear for snowy conditions",
        "cold weather parka for snow day",
    ],
    "windy": [
        "windbreaker shell jacket for windy weather",
        "wind resistant light outer layer",
        "protective jacket for strong wind",
    ],
    "humid": [
        "breathable cotton t shirt for humid weather",
        "moisture wicking lightweight clothing for humidity",
        "airy summer clothing for humid climate",
    ],
    "dry": [
        "regular casual clothing for dry weather",
        "everyday outfit without rain or snow",
        "standard daily wear for clear dry conditions",
    ],
}

LIGHTWEIGHT_KEYWORDS = {
    "tee",
    "tshirt",
    "t-shirt",
    "shirt",
    "tank",
    "camisole",
    "blouse",
    "polo",
    "shorts",
    "skirt",
}
HEAVY_KEYWORDS = {
    "coat",
    "parka",
    "puffer",
    "hoodie",
    "sweater",
    "fleece",
    "thermal",
    "wool",
    "jacket",
}
OUTERWEAR_KEYWORDS = {
    "jacket",
    "coat",
    "parka",
    "windbreaker",
    "raincoat",
    "outerwear",
    "shell",
}
PRECIPITATION_KEYWORDS = {
    "raincoat",
    "waterproof",
    "water resistant",
    "snow",
    "parka",
    "boot",
}

TEMP_MIN_MARGIN = 0.004
EXTREME_TEMP_MIN_MARGIN = 0.010
PRECIPITATION_MIN_MARGIN = 0.010


def _safe_text(raw: Optional[str]) -> str:
    return (raw or "").strip().lower()


def _metadata_blob(category: Optional[str], subcategory: Optional[str]) -> str:
    return f"{_safe_text(category)} {_safe_text(subcategory)}".strip()


def _contains_any(text: str, words: Iterable[str]) -> bool:
    return any(word in text for word in words)


def _encode_image(image_path: str) -> torch.Tensor:
    with Image.open(image_path).convert("RGB") as image:
        image_tensor = preprocess(image).unsqueeze(0).to(device)
    with torch.no_grad():
        image_features = model.encode_image(image_tensor)
        image_features /= image_features.norm(dim=-1, keepdim=True)
    return image_features


def _encode_text(prompts: List[str]) -> torch.Tensor:
    text_tokens = clip.tokenize(prompts).to(device)
    with torch.no_grad():
        text_features = model.encode_text(text_tokens)
        text_features /= text_features.norm(dim=-1, keepdim=True)
    return text_features


def _score_prompt_groups(
    image_features: torch.Tensor,
    prompt_groups: Dict[str, List[str]],
) -> Dict[str, float]:
    all_prompts: List[str] = []
    label_to_indices: Dict[str, List[int]] = {}

    for label, prompts in prompt_groups.items():
        indices: List[int] = []
        for prompt in prompts:
            indices.append(len(all_prompts))
            all_prompts.append(prompt)
        label_to_indices[label] = indices

    text_features = _encode_text(all_prompts)
    with torch.no_grad():
        similarities = (image_features @ text_features.T).squeeze(0).tolist()

    scores: Dict[str, float] = {}
    for label, indices in label_to_indices.items():
        label_scores = sorted((similarities[i] for i in indices), reverse=True)
        # Mean of top prompts stabilizes noise while keeping confident matches strong.
        top_scores = label_scores[:2]
        scores[label] = sum(top_scores) / max(len(top_scores), 1)

    return scores


def _apply_temperature_priors(
    scores: Dict[str, float],
    category: Optional[str],
    subcategory: Optional[str],
) -> None:
    blob = _metadata_blob(category, subcategory)

    if _contains_any(blob, LIGHTWEIGHT_KEYWORDS):
        scores["hot"] += 0.012
        scores["warm"] += 0.009
        scores["freezing"] -= 0.012
        scores["cold"] -= 0.008

    if _contains_any(blob, HEAVY_KEYWORDS):
        scores["freezing"] += 0.012
        scores["cold"] += 0.009
        scores["warm"] -= 0.007
        scores["hot"] -= 0.012


def _apply_weather_priors(
    scores: Dict[str, float],
    category: Optional[str],
    subcategory: Optional[str],
) -> None:
    blob = _metadata_blob(category, subcategory)
    is_outerwear_like = _contains_any(blob, OUTERWEAR_KEYWORDS)
    is_precipitation_specific = _contains_any(blob, PRECIPITATION_KEYWORDS)
    is_lightweight = _contains_any(blob, LIGHTWEIGHT_KEYWORDS)

    if is_lightweight:
        scores["humid"] += 0.010
        scores["dry"] += 0.010
        scores["snowy"] -= 0.012
        scores["rainy"] -= 0.008

    if not is_outerwear_like and not is_precipitation_specific:
        scores["dry"] += 0.010
        scores["rainy"] -= 0.008
        scores["snowy"] -= 0.010

    if is_precipitation_specific:
        scores["rainy"] += 0.010
        scores["snowy"] += 0.010


def _top_two(scores: Dict[str, float]) -> Tuple[Tuple[str, float], Tuple[str, float]]:
    ordered = sorted(scores.items(), key=lambda item: item[1], reverse=True)
    best = ordered[0]
    second = ordered[1] if len(ordered) > 1 else ("", float("-inf"))
    return best, second


def _score_probabilities(scores: Dict[str, float]) -> Dict[str, float]:
    if not scores:
        return {}
    labels = list(scores.keys())
    values = torch.tensor([scores[label] for label in labels], dtype=torch.float32)
    probs = torch.softmax(values, dim=0).tolist()
    return {label: float(probs[index]) for index, label in enumerate(labels)}


def _selected_margin(scores: Dict[str, float], selected_label: str) -> float:
    if selected_label not in scores or len(scores) <= 1:
        return 0.0
    selected_score = scores[selected_label]
    best_other = max(
        score
        for label, score in scores.items()
        if label != selected_label
    )
    return selected_score - best_other


def _select_temperature(scores: Dict[str, float]) -> str:
    (best_label, best_score), (_, second_score) = _top_two(scores)
    margin = best_score - second_score

    if margin < TEMP_MIN_MARGIN:
        return "warm" if scores.get("warm", 0.0) >= scores.get("cool", 0.0) else "cool"

    if best_label in {"freezing", "hot"} and margin < EXTREME_TEMP_MIN_MARGIN:
        moderate_labels = ("cold", "cool", "warm")
        return max(moderate_labels, key=lambda key: scores.get(key, float("-inf")))

    return best_label


def _select_weather(
    scores: Dict[str, float],
    category: Optional[str],
    subcategory: Optional[str],
) -> str:
    (best_label, best_score), (_, second_score) = _top_two(scores)
    margin = best_score - second_score
    blob = _metadata_blob(category, subcategory)
    is_precipitation_specific = _contains_any(blob, PRECIPITATION_KEYWORDS)

    if margin < TEMP_MIN_MARGIN:
        return max(("dry", "humid", "windy"), key=lambda key: scores.get(key, float("-inf")))

    if best_label in {"rainy", "snowy"} and not is_precipitation_specific:
        non_precip = max(
            ("dry", "humid", "windy"),
            key=lambda key: scores.get(key, float("-inf")),
        )
        if (best_score - scores.get(non_precip, float("-inf"))) < PRECIPITATION_MIN_MARGIN:
            return non_precip

    return best_label


def classify_clothing_weather(
    image_path: str,
    category: Optional[str] = None,
    subcategory: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Returns classifier labels plus confidence metadata used by upload logic:
    {
        "temperature": "<label>",
        "weather": "<label>",
        "temperature_confidence": <float>,
        "weather_confidence": <float>,
        "temperature_margin": <float>,
        "weather_margin": <float>,
        "is_precipitation_specific": <bool>,
    }
    """
    image_features = _encode_image(image_path)

    temp_scores = _score_prompt_groups(image_features, TEMPERATURE_PROMPTS)
    weather_scores = _score_prompt_groups(image_features, WEATHER_PROMPTS)

    _apply_temperature_priors(temp_scores, category, subcategory)
    _apply_weather_priors(weather_scores, category, subcategory)

    selected_temperature = _select_temperature(temp_scores)
    selected_weather = _select_weather(weather_scores, category, subcategory)

    temp_probabilities = _score_probabilities(temp_scores)
    weather_probabilities = _score_probabilities(weather_scores)

    blob = _metadata_blob(category, subcategory)
    is_precipitation_specific = _contains_any(blob, PRECIPITATION_KEYWORDS)

    return {
        "temperature": selected_temperature,
        "weather": selected_weather,
        "temperature_confidence": round(temp_probabilities.get(selected_temperature, 0.0), 4),
        "weather_confidence": round(weather_probabilities.get(selected_weather, 0.0), 4),
        "temperature_margin": round(_selected_margin(temp_scores, selected_temperature), 4),
        "weather_margin": round(_selected_margin(weather_scores, selected_weather), 4),
        "is_precipitation_specific": is_precipitation_specific,
    }


def normalize_scores(score_dict: Dict[str, float]) -> Dict[str, float]:
    total = sum(score_dict.values())
    if total == 0:
        return score_dict
    return {k: v / total for k, v in score_dict.items()}


def process_clothing_item(item) -> None:
    try:
        result = classify_clothing_weather(
            item.image.path,
            category=getattr(item, "category", None),
            subcategory=getattr(item, "subcategory", None),
        )
        item.detected_temp = result.get("temperature")
        item.detected_weather = result.get("weather")
        item.save(update_fields=["detected_temp", "detected_weather"])
    except Exception as e:
        print(f"Classification failed for item {item.id}: {e}")


def process_all_items(queryset) -> None:
    for item in queryset:
        if not item.detected_temp or not item.detected_weather:
            process_clothing_item(item)
