from typing import Dict, Iterable, List, Optional

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
) -> List[Dict]:
    tops = list(topwear)
    bottoms = list(bottomwear)
    shoes = list(footwear)
    outers = list(outerwear)

    policy = _outerwear_policy(temperature)

    outfits: List[Dict] = []

    def add_base():
        for top in tops:
            for bottom in bottoms:
                for shoe in shoes:
                    outfits.append(
                        {
                            "topwear": top,
                            "bottomwear": bottom,
                            "shoes": shoe,
                            "outerwear": None,
                        }
                    )

    def add_with_outerwear():
        for top in tops:
            for bottom in bottoms:
                for shoe in shoes:
                    for outer in outers:
                        outfits.append(
                            {
                                "topwear": top,
                                "bottomwear": bottom,
                                "shoes": shoe,
                                "outerwear": outer,
                            }
                        )

    if policy == "required":
        if not outers:
            return []
        add_with_outerwear()
        return outfits

    if policy in {"preferred", "optional"}:
        add_base()
        if outers:
            add_with_outerwear()
        return outfits

    if policy == "discouraged":
        add_base()
        return outfits

    add_base()
    return outfits
