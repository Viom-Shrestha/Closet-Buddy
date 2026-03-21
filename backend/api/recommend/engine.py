import random
from typing import Dict, List, Optional

from ..models import ClothingItem
from . import filters, generator, scoring


def _limit_items(items: List[ClothingItem], max_items: int) -> List[ClothingItem]:
    if len(items) <= max_items:
        return list(items)
    items = list(items)
    random.shuffle(items)
    return items[:max_items]


def recommend_outfits(
    user,
    weather: Dict,
    occasion: Optional[str] = None,
    prompt: Optional[str] = None,
    limit: int = 5,
) -> List[Dict]:
    items = list(ClothingItem.objects.filter(user=user))
    if not items:
        return []

    normalized_weather = filters.normalize_weather(weather or {})
    normalized_occasion = filters.normalize_occasion(occasion)

    filtered_items = filters.filter_items(items, normalized_weather)
    topwear, bottomwear, footwear, outerwear = filters.split_by_category(filtered_items)

    if not topwear or not bottomwear or not footwear:
        return []

    topwear = _limit_items(topwear, 10)
    bottomwear = _limit_items(bottomwear, 10)
    footwear = _limit_items(footwear, 10)
    outerwear = _limit_items(outerwear, 5)

    outfits = generator.generate_outfits(
        topwear,
        bottomwear,
        footwear,
        outerwear,
        normalized_weather.get("temperature", ""),
    )

    if not outfits:
        return []

    text_prompt = scoring.build_prompt(prompt, normalized_occasion, normalized_weather)

    scored = []
    for outfit in outfits:
        score = scoring.final_score(outfit, normalized_weather, normalized_occasion, text_prompt)
        scored.append((score, outfit))

    scored.sort(key=lambda pair: pair[0], reverse=True)

    results: List[Dict] = []
    for _, outfit in scored[:limit]:
        results.append(
            {
                "topwear_id": outfit["topwear"].id,
                "bottomwear_id": outfit["bottomwear"].id,
                "shoes_id": outfit["shoes"].id,
                "outerwear_id": outfit["outerwear"].id if outfit.get("outerwear") else None,
            }
        )

    return results
