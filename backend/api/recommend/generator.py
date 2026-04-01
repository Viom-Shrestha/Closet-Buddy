from typing import Dict, Iterable, List

from ..models import ClothingItem


def _outerwear_policy(temperature: str) -> str:
    if temperature == "freezing":
        return "required"
    if temperature == "cold":
        return "preferred"
    if temperature == "cool":
        return "optional"
    if temperature in {"warm", "hot"}:
        return "discouraged"
    return "optional"


def generate_outfits(
    topwear: Iterable[ClothingItem],
    bottomwear: Iterable[ClothingItem],
    footwear: Iterable[ClothingItem],
    outerwear: Iterable[ClothingItem],
    temperature: str,
    combo_limit: int = 50,
) -> List[Dict]:
    tops = list(topwear)
    bottoms = list(bottomwear)
    shoes = list(footwear)
    outers = list(outerwear)

    policy = _outerwear_policy(temperature)

    outfits: List[Dict] = []

    def _append(top: ClothingItem, bottom: ClothingItem, shoe: ClothingItem, outer: ClothingItem | None) -> bool:
        outfits.append(
            {
                "topwear": top,
                "bottomwear": bottom,
                "shoes": shoe,
                "outerwear": outer,
            }
        )
        return len(outfits) >= combo_limit

    if policy == "required":
        if not outers:
            return []
        for top in tops:
            for bottom in bottoms:
                for shoe in shoes:
                    for outer in outers:
                        if _append(top, bottom, shoe, outer):
                            return outfits
        return outfits

    if policy in {"preferred", "optional", "discouraged"}:
        # Base combinations first: pools are already context-ranked in engine.
        for top in tops:
            for bottom in bottoms:
                for shoe in shoes:
                    if _append(top, bottom, shoe, None):
                        return outfits

        if policy in {"preferred", "optional"} and outers:
            for top in tops:
                for bottom in bottoms:
                    for shoe in shoes:
                        for outer in outers:
                            if _append(top, bottom, shoe, outer):
                                return outfits
        return outfits

    # Fallback policy path.
    for top in tops:
        for bottom in bottoms:
            for shoe in shoes:
                if _append(top, bottom, shoe, None):
                    return outfits
    return outfits
