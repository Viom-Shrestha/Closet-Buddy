import random
from typing import Dict, List, Optional, Set, Tuple

from ..models import ClothingItem
from . import filters, generator, scoring


def _rank_items_for_context(
    items: List[ClothingItem],
    weather: Dict,
    occasion: Optional[str],
    max_items: int,
) -> List[ClothingItem]:
    scored: List[tuple] = []
    for item in items:
        context_score = scoring.item_context_score(item, weather, occasion)
        # Tiny jitter avoids hard recency bias when many items tie.
        scored.append((context_score + random.uniform(0.0, 0.001), item))

    scored.sort(key=lambda pair: pair[0], reverse=True)
    return [item for _, item in scored[:max_items]]


def _outfit_item_ids(outfit: Dict) -> Set[int]:
    ids: Set[int] = {
        outfit["topwear"].id,
        outfit["bottomwear"].id,
        outfit["shoes"].id,
    }
    outer = outfit.get("outerwear")
    if outer:
        ids.add(outer.id)
    return ids


def _diversity_rerank(scored: List[Tuple[float, Dict]], limit: int) -> List[Dict]:
    if limit <= 0 or not scored:
        return []

    remaining = list(scored)
    remaining.sort(key=lambda pair: pair[0], reverse=True)

    selected: List[Tuple[float, Dict, Set[int]]] = []

    while remaining and len(selected) < limit:
        if not selected:
            score, outfit = remaining.pop(0)
            selected.append((score, outfit, _outfit_item_ids(outfit)))
            continue

        best_index = 0
        best_adjusted = float("-inf")
        for index, (score, outfit) in enumerate(remaining):
            candidate_ids = _outfit_item_ids(outfit)
            max_overlap = 0.0
            for _, _, chosen_ids in selected:
                union = candidate_ids | chosen_ids
                overlap = (len(candidate_ids & chosen_ids) / len(union)) if union else 0.0
                if overlap > max_overlap:
                    max_overlap = overlap

            # Encourage variation without sacrificing quality.
            adjusted = score - (0.18 * max_overlap)
            if adjusted > best_adjusted:
                best_adjusted = adjusted
                best_index = index

        score, outfit = remaining.pop(best_index)
        selected.append((score, outfit, _outfit_item_ids(outfit)))

    return [outfit for _, outfit, _ in selected]


def recommend_outfits(
    user,
    weather: Dict,
    occasion: Optional[str] = None,
    prompt: Optional[str] = None,
    limit: int = 3,
) -> Dict:
    items = list(ClothingItem.objects.filter(user=user))
    fallback_used = False
    occasion_fallback_used = False

    requested_occasion = (occasion or "").strip()
    normalized_occasion = filters.canonical_occasion(occasion)
    scoring_occasion = normalized_occasion

    if not items:
        return {
            "results": [],
            "fallback_used": fallback_used,
            "occasion_fallback_used": occasion_fallback_used,
            "occasion_applied": "",
        }

    # If user asks for an occasion, try to constrain to wardrobe items that signal it.
    # If that pool cannot form full outfits, we fall back to all items and clear occasion bias.
    candidate_items = items
    if requested_occasion:
        if normalized_occasion:
            occasion_items = [
                item
                for item in items
                if normalized_occasion in filters.item_occasion_signals(item)
            ]
            occ_topwear, occ_bottomwear, occ_footwear, _ = filters.split_by_category(occasion_items)
            if occ_topwear and occ_bottomwear and occ_footwear:
                candidate_items = occasion_items
            else:
                occasion_fallback_used = True
                scoring_occasion = ""
        else:
            occasion_fallback_used = True
            scoring_occasion = ""

    normalized_weather = filters.normalize_weather(weather or {})

    filtered_items = filters.filter_items(candidate_items, normalized_weather)
    topwear, bottomwear, footwear, outerwear = filters.split_by_category(filtered_items)

    # Occasion-constrained pool might be valid generally but too strict for current weather.
    if requested_occasion and scoring_occasion and (not topwear or not bottomwear or not footwear):
        occasion_fallback_used = True
        scoring_occasion = ""
        filtered_items = filters.filter_items(items, normalized_weather)
        topwear, bottomwear, footwear, outerwear = filters.split_by_category(filtered_items)

    # If weather filtering is too strict, gracefully fall back to all items.
    if not topwear or not bottomwear or not footwear:
        fallback_used = True
        topwear, bottomwear, footwear, outerwear = filters.split_by_category(items)

    if not topwear or not bottomwear or not footwear:
        return {
            "results": [],
            "fallback_used": fallback_used,
            "occasion_fallback_used": occasion_fallback_used,
            "occasion_applied": scoring_occasion,
        }

    # Phase 1: rank each slot pool by weather+occasion context and keep top-N only.
    topwear = _rank_items_for_context(topwear, normalized_weather, scoring_occasion, 8)
    bottomwear = _rank_items_for_context(bottomwear, normalized_weather, scoring_occasion, 8)
    footwear = _rank_items_for_context(footwear, normalized_weather, scoring_occasion, 8)
    outerwear = _rank_items_for_context(outerwear, normalized_weather, scoring_occasion, 4)

    outfits = generator.generate_outfits(
        topwear,
        bottomwear,
        footwear,
        outerwear,
        normalized_weather.get("temperature", ""),
        combo_limit=50,
    )

    # If strict layering policy yields no outfits, retry with optional outerwear.
    if not outfits:
        fallback_used = True
        outfits = generator.generate_outfits(
            topwear,
            bottomwear,
            footwear,
            outerwear,
            "cool",
            combo_limit=50,
        )

    if not outfits:
        return {
            "results": [],
            "fallback_used": fallback_used,
            "occasion_fallback_used": occasion_fallback_used,
            "occasion_applied": scoring_occasion,
        }

    # Phase 2: score full combinations from the pre-vetted pool.
    text_prompt = scoring.build_prompt(prompt, scoring_occasion, normalized_weather)

    scored = []
    for outfit in outfits:
        score = scoring.final_score(outfit, normalized_weather, scoring_occasion, text_prompt)
        scored.append((score, outfit))

    scored.sort(key=lambda pair: pair[0], reverse=True)

    selected_outfits = _diversity_rerank(scored, limit)

    results: List[Dict] = []
    for outfit in selected_outfits:
        results.append(
            {
                "topwear_id": outfit["topwear"].id,
                "bottomwear_id": outfit["bottomwear"].id,
                "shoes_id": outfit["shoes"].id,
                "outerwear_id": outfit["outerwear"].id if outfit.get("outerwear") else None,
            }
        )

    return {
        "results": results,
        "fallback_used": fallback_used,
        "occasion_fallback_used": occasion_fallback_used,
        "occasion_applied": scoring_occasion,
    }
