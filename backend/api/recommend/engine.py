import random
from typing import Dict, List, Optional, Set, Tuple

from ..models import ClothingItem
from . import filters, generator, scoring


def _rank_items_for_context(
    items: List[ClothingItem],
    weather: Dict,
    occasion: Optional[str],
    max_items: int,
    debug_slot: Optional[str] = None,
    debug_trace: Optional[Dict] = None,
) -> List[ClothingItem]:
    scored: List[tuple] = []
    for item in items:
        context_score = scoring.item_context_score(item, weather, occasion)
        # Tiny jitter avoids hard recency bias when many items tie.
        scored.append((context_score + random.uniform(0.0, 0.001), item))

    scored.sort(key=lambda pair: pair[0], reverse=True)
    selected = [item for _, item in scored[:max_items]]
    if debug_trace is not None and debug_slot:
        debug_trace.setdefault("phase1_context_ranking", {})[debug_slot] = {
            "input_count": len(items),
            "selected_count": len(selected),
            "selected": [
                {"item_id": item.id, "context_score": round(score, 4)}
                for score, item in scored[:max_items]
            ],
        }
    return selected


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


def _diversity_rerank(
    scored: List[Tuple[float, Dict]],
    limit: int,
    debug_trace: Optional[Dict] = None,
) -> List[Dict]:
    if limit <= 0 or not scored:
        return []

    remaining = list(scored)
    remaining.sort(key=lambda pair: pair[0], reverse=True)

    selected: List[Tuple[float, Dict, Set[int]]] = []

    while remaining and len(selected) < limit:
        if not selected:
            score, outfit = remaining.pop(0)
            selected.append((score, outfit, _outfit_item_ids(outfit)))
            if debug_trace is not None:
                debug_trace.setdefault("phase3_diversity_rerank", []).append(
                    {
                        "picked_top_seed": True,
                        "base_score": round(score, 4),
                        "adjusted_score": round(score, 4),
                        "outfit": {
                            "topwear_id": outfit["topwear"].id,
                            "bottomwear_id": outfit["bottomwear"].id,
                            "shoes_id": outfit["shoes"].id,
                            "outerwear_id": outfit["outerwear"].id if outfit.get("outerwear") else None,
                        },
                    }
                )
            continue

        best_index = 0
        best_adjusted = float("-inf")
        best_overlap = 0.0
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
                best_overlap = max_overlap

        score, outfit = remaining.pop(best_index)
        selected.append((score, outfit, _outfit_item_ids(outfit)))
        if debug_trace is not None:
            debug_trace.setdefault("phase3_diversity_rerank", []).append(
                {
                    "picked_top_seed": False,
                    "base_score": round(score, 4),
                    "max_overlap": round(best_overlap, 4),
                    "adjusted_score": round(best_adjusted, 4),
                    "outfit": {
                        "topwear_id": outfit["topwear"].id,
                        "bottomwear_id": outfit["bottomwear"].id,
                        "shoes_id": outfit["shoes"].id,
                        "outerwear_id": outfit["outerwear"].id if outfit.get("outerwear") else None,
                    },
                }
            )

    return [outfit for _, outfit, _ in selected]


def recommend_outfits(
    user,
    weather: Dict,
    occasion: Optional[str] = None,
    prompt: Optional[str] = None,
    limit: int = 3,
    debug: bool = False,
) -> Dict:
    items = list(
        ClothingItem.objects.filter(
            user=user,
            storage_unit__is_put_away=False,
        )
    )
    fallback_used = False
    occasion_fallback_used = False
    debug_trace: Dict = {"debug_enabled": bool(debug)} if debug else {}

    requested_occasion = (occasion or "").strip()
    normalized_occasion = filters.canonical_occasion(occasion)
    scoring_occasion = normalized_occasion

    if not items:
        return {
            "results": [],
            "fallback_used": fallback_used,
            "occasion_fallback_used": occasion_fallback_used,
            "occasion_applied": "",
            "insufficient_wardrobe": True,
            "missing_slots": ["topwear", "bottomwear", "footwear"],
            **({"debug": debug_trace} if debug else {}),
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
            if debug:
                debug_trace["occasion_filter"] = {
                    "requested_occasion": requested_occasion,
                    "normalized_occasion": normalized_occasion,
                    "candidate_count": len(occasion_items),
                }
            occ_topwear, occ_bottomwear, occ_footwear, _ = filters.split_by_category(occasion_items)
            if occ_topwear and occ_bottomwear and occ_footwear:
                candidate_items = occasion_items
            else:
                occasion_fallback_used = True
                scoring_occasion = ""
        else:
            occasion_fallback_used = True
            scoring_occasion = ""
            if debug:
                debug_trace["occasion_filter"] = {
                    "requested_occasion": requested_occasion,
                    "normalized_occasion": "",
                    "candidate_count": 0,
                    "fallback_reason": "unrecognized_occasion",
                }

    normalized_weather = filters.normalize_weather(weather or {})
    if debug:
        debug_trace["input_counts"] = {
            "wardrobe_total": len(items),
            "candidate_total": len(candidate_items),
        }
        debug_trace["normalized_weather"] = normalized_weather

    filtered_items = filters.filter_items(candidate_items, normalized_weather)
    topwear, bottomwear, footwear, outerwear = filters.split_by_category(filtered_items)
    if debug:
        debug_trace["post_weather_filter"] = {
            "filtered_total": len(filtered_items),
            "topwear": len(topwear),
            "bottomwear": len(bottomwear),
            "footwear": len(footwear),
            "outerwear": len(outerwear),
        }

    # Occasion-constrained pool might be valid generally but too strict for current weather.
    if requested_occasion and scoring_occasion and (not topwear or not bottomwear or not footwear):
        occasion_fallback_used = True
        scoring_occasion = ""
        filtered_items = filters.filter_items(items, normalized_weather)
        topwear, bottomwear, footwear, outerwear = filters.split_by_category(filtered_items)
        if debug:
            debug_trace["occasion_weather_fallback"] = {
                "triggered": True,
                "topwear": len(topwear),
                "bottomwear": len(bottomwear),
                "footwear": len(footwear),
                "outerwear": len(outerwear),
            }

    # If weather filtering is too strict, gracefully fall back to all items.
    if not topwear or not bottomwear or not footwear:
        fallback_used = True
        topwear, bottomwear, footwear, outerwear = filters.split_by_category(items)
        if debug:
            debug_trace["hard_weather_fallback"] = {
                "triggered": True,
                "topwear": len(topwear),
                "bottomwear": len(bottomwear),
                "footwear": len(footwear),
                "outerwear": len(outerwear),
            }

    if not topwear or not bottomwear or not footwear:
        missing = []
        if not topwear:
            missing.append("topwear")
        if not bottomwear:
            missing.append("bottomwear")
        if not footwear:
            missing.append("footwear")
        return {
            "results": [],
            "fallback_used": fallback_used,
            "occasion_fallback_used": occasion_fallback_used,
            "occasion_applied": scoring_occasion,
            "insufficient_wardrobe": True,
            "missing_slots": missing,
            **({"debug": debug_trace} if debug else {}),
        }

    # Phase 1: rank each slot pool by weather+occasion context and keep top-N only.
    topwear = _rank_items_for_context(topwear, normalized_weather, scoring_occasion, 8, "topwear", debug_trace if debug else None)
    bottomwear = _rank_items_for_context(
        bottomwear,
        normalized_weather,
        scoring_occasion,
        8,
        "bottomwear",
        debug_trace if debug else None,
    )
    footwear = _rank_items_for_context(
        footwear,
        normalized_weather,
        scoring_occasion,
        8,
        "footwear",
        debug_trace if debug else None,
    )
    outerwear = _rank_items_for_context(
        outerwear,
        normalized_weather,
        scoring_occasion,
        4,
        "outerwear",
        debug_trace if debug else None,
    )

    outfits = generator.generate_outfits(
        topwear,
        bottomwear,
        footwear,
        outerwear,
        normalized_weather.get("temperature", ""),
        combo_limit=50,
    )
    if debug:
        debug_trace["phase2_generation"] = {
            "generated_count": len(outfits),
            "temperature_policy": normalized_weather.get("temperature", ""),
        }

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
        if debug:
            debug_trace["phase2_generation_retry"] = {
                "generated_count": len(outfits),
                "temperature_policy": "cool",
            }

    if not outfits:
        return {
            "results": [],
            "fallback_used": fallback_used,
            "occasion_fallback_used": occasion_fallback_used,
            "occasion_applied": scoring_occasion,
            **({"debug": debug_trace} if debug else {}),
        }

    # Phase 2: score full combinations from the pre-vetted pool.
    text_prompt = scoring.build_prompt(prompt, scoring_occasion, normalized_weather)

    scored = []
    for outfit in outfits:
        score = scoring.final_score(outfit, normalized_weather, scoring_occasion, text_prompt)
        scored.append((score, outfit))

    scored.sort(key=lambda pair: pair[0], reverse=True)
    if debug:
        debug_trace["phase2_scoring"] = [
            {
                "score": round(score, 4),
                "outfit": {
                    "topwear_id": outfit["topwear"].id,
                    "bottomwear_id": outfit["bottomwear"].id,
                    "shoes_id": outfit["shoes"].id,
                    "outerwear_id": outfit["outerwear"].id if outfit.get("outerwear") else None,
                },
            }
            for score, outfit in scored
        ]

    selected_outfits = _diversity_rerank(scored, limit, debug_trace if debug else None)

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
        **({"debug": debug_trace} if debug else {}),
    }
