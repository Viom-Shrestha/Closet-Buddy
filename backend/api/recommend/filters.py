from typing import Dict, Iterable, List, Optional, Tuple

from ..models import ClothingItem
from ..metadata_normalization import (
    coerce_temperature_label,
    coerce_weather_label,
    normalize_attributes,
    normalize_token,
)


SHOE_SLOT_KEYS = (
    "shoe",
    "sneaker",
    "boot",
    "heel",
    "footwear",
    "slipper",
    "sandal",
    "loafer",
)

BOTTOM_SLOT_KEYS = (
    "pant",
    "trouser",
    "jean",
    "short",
    "skirt",
    "bottom",
    "jogger",
    "legging",
    "cargo",
)

OUTERWEAR_SLOT_KEYS = (
    "jacket",
    "coat",
    "blazer",
    "cardigan",
    "hoodie",
    "outerwear",
    "parka",
    "trench",
)


COLD_SIGNALS = {
    "wool", "knit", "hooded", "long sleeve", "boots", "leather",
    "full length", "fleece", "thermal", "padded", "quilted",
    "puffer", "down", "insulated", "sherpa", "fur", "corduroy",
    "turtleneck", "heavyweight", "thick", "flannel", "tweed",
    "cable knit", "ribbed knit", "sweater", "jumper", "pullover",
    "coat", "parka", "trench", "anorak", "windbreaker", "overcoat",
}

WARM_SIGNALS = {
    "linen", "cotton", "short sleeve", "sleeveless", "sandals",
    "cropped", "knee length", "mini", "midi", "breathable",
    "lightweight", "sheer", "mesh", "chiffon", "silk", "satin",
    "tank", "camisole", "halter", "backless", "open toe",
    "flip flop", "espadrille", "t shirt", "t-shirt", "tee", "polo",
    "chambray", "jersey", "voile", "lace", "eyelet", "tropical",
    "resort", "beach", "summer", "shorts",
}

RAIN_SIGNALS = {
    "hooded", "leather", "boots", "waterproof", "water resistant",
    "waxed", "rubber", "raincoat", "rain jacket", "trench",
    "mackintosh", "galoshes", "wellington",
}

SNOW_REQUIRED = {
    "wool", "knit", "boots", "long sleeve", "hooded", "fleece",
    "thermal", "padded", "quilted", "puffer", "down", "insulated",
    "sherpa", "turtleneck", "heavyweight", "snow boot", "winterized",
}

WIND_SIGNALS = {
    "windbreaker", "anorak", "hooded", "waxed", "trench",
    "layered", "tight knit",
}

HUMID_SIGNALS = {
    "linen", "cotton", "breathable", "moisture wicking",
    "lightweight", "loose", "chambray",
}

PRECIP_PROFILE_ATTR_SIGNALS = {
    "waterproof",
    "water resistant",
    "raincoat",
    "rain jacket",
    "shell",
    "snow",
    "snow boot",
    "winterized",
    "galoshes",
    "wellington",
}

PRECIP_PROFILE_TEXT_KEYS = {
    "rain",
    "snow",
    "waterproof",
    "water resistant",
    "raincoat",
    "shell",
    "parka",
    "windbreaker",
    "trench",
    "boot",
}

CANONICAL_OCCASIONS = {
    "casual",
    "formal",
    "office",
    "party",
    "date",
    "traditional",
    "sport",
    "home",
    "travel",
    "beach",
    "street",
    "outdoor",
    "workout",
}

OCCASION_ALIASES = {
    "date night": "date",
    "night out": "party",
    "streetwear": "street",
    "sporty": "sport",
    "active": "sport",
    "athletic": "sport",
    "gym": "sport",
    "fitness": "sport",
    "any": "",
    "any occasion": "",
    "none": "",
}

def attr_set(item: ClothingItem) -> set:
    return set(normalize_attributes(item.attributes or []))


def _slot_text(item: ClothingItem) -> str:
    return normalize_token(f"{item.category or ''} {item.subcategory or ''}")


def _has_any_key(text: str, keys: Iterable[str]) -> bool:
    return any(key in text for key in keys)


def is_shoe(item: ClothingItem) -> bool:
    return _has_any_key(_slot_text(item), SHOE_SLOT_KEYS)


def is_bottom(item: ClothingItem) -> bool:
    return _has_any_key(_slot_text(item), BOTTOM_SLOT_KEYS)


def is_outerwear(item: ClothingItem) -> bool:
    return _has_any_key(_slot_text(item), OUTERWEAR_SLOT_KEYS)


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


def _conflicts_with_temperature(item: ClothingItem, temperature: str) -> bool:
    detected = coerce_temperature_label(item.detected_temp, allow_unknown=True) or ""
    if detected:
        hard_conflicts = {
            "freezing": {"warm", "hot"},
            "cold": {"hot"},
            "warm": {"freezing"},
            "hot": {"freezing", "cold"},
        }
        return detected in hard_conflicts.get(temperature, set())

    attrs = attr_set(item)
    if not attrs:
        return False  # Unlabelled; let it through and down-score later.

    warm_count = len(attrs & WARM_SIGNALS)
    cold_count = len(attrs & COLD_SIGNALS)

    if temperature in {"freezing", "cold"}:
        # Conflict if item is predominantly warm-signalled.
        return warm_count > cold_count and warm_count > 0

    if temperature in {"warm", "hot"}:
        # Conflict if item is predominantly cold-signalled.
        return cold_count > warm_count and cold_count > 0

    return False


def _fails_snow_requirement(attr_set: set) -> bool:
    if not attr_set:
        return False
    return not bool(attr_set & SNOW_REQUIRED)


def has_precipitation_profile(item: ClothingItem) -> bool:
    attrs = attr_set(item)
    if attrs & PRECIP_PROFILE_ATTR_SIGNALS:
        return True

    text = _slot_text(item)
    return any(key in text for key in PRECIP_PROFILE_TEXT_KEYS)


def filter_items(
    items: Iterable[ClothingItem],
    weather: Dict,
) -> List[ClothingItem]:
    temperature = normalize_token(weather.get("temperature"))
    condition = normalize_token(weather.get("weather"))

    filtered: List[ClothingItem] = []
    for item in items:
        if temperature and _conflicts_with_temperature(item, temperature):
            continue

        if condition == "snowy":
            detected_weather = normalize_token(item.detected_weather)
            if detected_weather in {"rainy", "snowy"} and not has_precipitation_profile(item):
                detected_weather = ""
            if detected_weather:
                if detected_weather not in {"snowy", "cold", "dry"}:
                    continue
            else:
                attrs = attr_set(item)
                if _fails_snow_requirement(attrs):
                    continue

        # Windy/humid are soft preferences handled in scoring, not hard filters.
        filtered.append(item)

    return filtered


def normalize_weather(weather: Dict) -> Dict[str, str]:
    temperature = coerce_temperature_label(weather.get("temperature"), allow_unknown=True) or ""
    condition = coerce_weather_label(weather.get("weather"), allow_unknown=True) or ""
    return {
        "temperature": temperature,
        "weather": condition,
    }


def canonical_occasion(value: Optional[str]) -> str:
    normalized = normalize_token(value)
    if not normalized:
        return ""
    alias_mapped = OCCASION_ALIASES.get(normalized, normalized)
    if alias_mapped in CANONICAL_OCCASIONS:
        return alias_mapped
    return ""


def item_occasion_signals(item: ClothingItem) -> set:
    signals = set()

    direct = canonical_occasion(item.occasion)
    if direct:
        signals.add(direct)

    for attr in attr_set(item):
        mapped = canonical_occasion(attr)
        if mapped:
            signals.add(mapped)

    return signals
