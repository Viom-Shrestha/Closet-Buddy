from typing import Dict, Iterable, List, Optional, Tuple

from ..models import ClothingItem


COLD_SIGNALS = {
    "wool",
    "knit",
    "hooded",
    "long sleeve",
    "boots",
    "leather",
    "full length",
}

WARM_SIGNALS = {
    "linen",
    "cotton",
    "short sleeve",
    "sleeveless",
    "sandals",
    "cropped",
    "knee length",
    "mini",
    "midi",
}

RAIN_SIGNALS = {"hooded", "leather", "boots"}

SNOW_REQUIRED = {"wool", "knit", "boots", "long sleeve", "hooded"}


def _normalize_text(value: Optional[str]) -> str:
    return (value or "").strip().lower()


def _attr_set(item: ClothingItem) -> set:
    raw = item.attributes or []
    return {str(a).strip().lower() for a in raw if a}


def _slot_text(item: ClothingItem) -> str:
    return f"{item.category or ''} {item.subcategory or ''}".lower()


def is_shoe(item: ClothingItem) -> bool:
    text = _slot_text(item)
    keys = ["shoe", "sneaker", "boot", "heel", "footwear", "slipper", "sandal", "loafer"]
    return any(key in text for key in keys)


def is_bottom(item: ClothingItem) -> bool:
    text = _slot_text(item)
    keys = ["pant", "trouser", "jean", "short", "skirt", "bottom", "jogger", "legging", "cargo"]
    return any(key in text for key in keys)


def is_outerwear(item: ClothingItem) -> bool:
    text = _slot_text(item)
    keys = ["jacket", "coat", "blazer", "cardigan", "hoodie", "outerwear", "parka", "trench"]
    return any(key in text for key in keys)


def split_by_category(items: Iterable[ClothingItem]) -> Tuple[List[ClothingItem], List[ClothingItem], List[ClothingItem], List[ClothingItem]]:
    topwear: List[ClothingItem] = []
    bottomwear: List[ClothingItem] = []
    footwear: List[ClothingItem] = []
    outerwear: List[ClothingItem] = []

    for item in items:
        if is_shoe(item):
            footwear.append(item)
        elif is_outerwear(item):
            outerwear.append(item)
        elif is_bottom(item):
            bottomwear.append(item)
        else:
            topwear.append(item)

    return topwear, bottomwear, footwear, outerwear


def _conflicts_with_temperature(attr_set: set, temperature: str) -> bool:
    if not attr_set:
        return False

    if temperature in {"freezing", "cold"}:
        has_warm = bool(attr_set & WARM_SIGNALS)
        has_cold = bool(attr_set & COLD_SIGNALS)
        return has_warm and not has_cold

    if temperature in {"warm", "hot"}:
        has_warm = bool(attr_set & WARM_SIGNALS)
        has_cold = bool(attr_set & COLD_SIGNALS)
        return has_cold and not has_warm

    return False


def _fails_snow_requirement(attr_set: set) -> bool:
    if not attr_set:
        return False
    return not bool(attr_set & SNOW_REQUIRED)


def filter_items(
    items: Iterable[ClothingItem],
    weather: Dict,
) -> List[ClothingItem]:
    temperature = _normalize_text(weather.get("temperature"))
    condition = _normalize_text(weather.get("weather"))

    filtered: List[ClothingItem] = []
    for item in items:
        attrs = _attr_set(item)

        if temperature and _conflicts_with_temperature(attrs, temperature):
            continue

        if condition == "snowy" and _fails_snow_requirement(attrs):
            continue

        filtered.append(item)

    return filtered


def normalize_weather(weather: Dict) -> Dict[str, str]:
    return {
        "temperature": _normalize_text(weather.get("temperature")),
        "weather": _normalize_text(weather.get("weather")),
    }


def normalize_occasion(value: Optional[str]) -> str:
    normalized = _normalize_text(value)
    aliases = {
        "any": "",
        "sports": "sport",
        "athletic": "sport",
        "gym": "sport",
        "work": "office",
        "workwear": "office",
        "business": "office",
        "dating": "date",
        "streetwear": "street",
    }
    return aliases.get(normalized, normalized)


def attr_set(item: ClothingItem) -> set:
    return _attr_set(item)
