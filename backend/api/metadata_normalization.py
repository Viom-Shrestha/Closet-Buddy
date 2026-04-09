import json
import re
from typing import List, Optional


ALLOWED_TEMPERATURES = {"freezing", "cold", "cool", "warm", "hot"}
ALLOWED_WEATHER = {"rainy", "snowy", "windy", "humid", "dry"}

TEMPERATURE_ALIASES = {
    "freezing cold": "freezing",
    "very cold": "freezing",
    "chilly": "cold",
    "mild": "cool",
    "moderate": "cool",
    "lukewarm": "warm",
    "very hot": "hot",
    "heat": "hot",
    "any": "",
    "all": "",
    "any temperature": "",
    "no preference": "",
}

WEATHER_ALIASES = {
    "rain": "rainy",
    "raining": "rainy",
    "wet": "rainy",
    "snow": "snowy",
    "snowing": "snowy",
    "wind": "windy",
    "humidity": "humid",
    "clear": "dry",
    "sunny": "dry",
    "cloudy": "dry",
    "overcast": "dry",
    "any": "",
    "all": "",
    "any weather": "",
    "no preference": "",
}

COLOR_ALIASES = {
    # Neutrals
    "gray": "grey",
    "charcoal": "black",
    "onyx": "black",
    "ebony": "black",
    "off white": "white",
    "offwhite": "white",
    "ivory": "white",
    "cream": "white",
    "silver": "grey",
    "slate": "grey",
    "taupe": "beige",
    "khaki": "beige",
    "tan": "beige",
    "sand": "beige",
    "camel": "beige",
    "chocolate": "brown",
    "espresso": "brown",
    "mocha": "brown",
    "rust": "brown",
    # Blues / greens
    "dark blue": "navy",
    "navy blue": "navy",
    "midnight blue": "navy",
    "sky blue": "blue",
    "baby blue": "blue",
    "royal blue": "blue",
    "cobalt": "blue",
    "azure": "blue",
    "forest": "green",
    "emerald": "green",
    "olive green": "olive",
    "army green": "olive",
    "military green": "olive",
    "mint": "sage",
    "seafoam": "sage",
    "teal blue": "teal",
    "teal green": "teal",
    "aqua": "turquoise",
    "cyan": "turquoise",
    "aquamarine": "turquoise",
    # Reds / pinks
    "maroon": "burgundy",
    "wine": "burgundy",
    "oxblood": "burgundy",
    "fuchsia": "pink",
    "magenta": "pink",
    "rose": "blush",
    "mauve": "blush",
    "dusty rose": "blush",
    "salmon": "coral",
    "peach": "coral",
    "terracotta": "coral",
    # Warm accents
    "gold": "mustard",
    "amber": "mustard",
    "ochre": "mustard",
    "saffron": "mustard",
    "burnt orange": "orange",
    "tangerine": "orange",
    # Purples
    "violet": "purple",
    "plum": "purple",
    "aubergine": "purple",
    "lilac": "lavender",
}

SUBCATEGORY_ALIASES = {
    # --- SHIRT ---
    "button-up": "shirt",
    "button up": "shirt",
    "button-down": "shirt",
    "button down": "shirt",
    "dress shirt": "shirt",
    "formal shirt": "shirt",
    "oxford shirt": "shirt",
    "flannel": "shirt",
    "flannel shirt": "shirt",

    # --- T-SHIRT ---
    "tee": "t-shirt",
    "tshirt": "t-shirt",
    "t shirt": "t-shirt",
    "graphic tee": "t-shirt",
    "graphic t-shirt": "t-shirt",

    # --- HOODIE ---
    "sweatshirt": "hoodie",
    "hooded sweatshirt": "hoodie",
    "pullover hoodie": "hoodie",
    "zip hoodie": "hoodie",
    "hoodie jacket": "hoodie",

    # --- SWEATER ---
    "jumper": "sweater",
    "knitwear": "sweater",
    "knitted sweater": "sweater",
    "cardigan": "sweater",
    "pullover": "sweater",

    # --- JACKET ---
    "coat": "jacket",
    "overcoat": "jacket",
    "blazer": "jacket",
    "windbreaker": "jacket",
    "parka": "jacket",
    "bomber": "jacket",
    "bomber jacket": "jacket",
    "denim jacket": "jacket",
    "leather jacket": "jacket",

    # --- JEANS ---
    "jean": "jeans",
    "denim": "jeans",
    "denim pants": "jeans",
    "skinny jeans": "jeans",
    "ripped jeans": "jeans",

    # --- PANTS ---
    "trouser": "pants",
    "trousers": "pants",
    "chinos": "pants",
    "slacks": "pants",
    "cargo pants": "pants",
    "joggers": "pants",
    "sweatpants": "pants",

    # --- SHORTS ---
    "short": "shorts",
    "denim shorts": "shorts",
    "cargo shorts": "shorts",
    "gym shorts": "shorts",

    # --- SKIRT ---
    "mini skirt": "skirt",
    "midi skirt": "skirt",
    "maxi skirt": "skirt",

    # --- DRESS ---
    "gown": "dress",
    "evening dress": "dress",
    "maxi dress": "dress",
    "mini dress": "dress",
    "midi dress": "dress",

    # --- SHOES ---
    # sneakers
    "sneaker": "sneakers",
    "sneakers": "sneakers",
    "trainer": "sneakers",
    "trainers": "sneakers",
    "running shoes": "sneakers",
    "gym shoes": "sneakers",
    "sports shoes": "sports shoes",

    # formal
    "formal": "formal shoes",
    "dress shoes": "formal shoes",
    "office shoes": "formal shoes",
    "oxford": "formal shoes",
    "derby": "formal shoes",

    # boots
    "boot": "boots",
    "ankle boots": "boots",
    "leather boots": "boots",

    # sandals
    "sandal": "sandals",
    "sandals": "sandals",
    "flip flops": "flip flops",
    "flip flop": "flip flops",
    "slides": "sandals",

    # heels
    "heel": "heels",
    "heels": "heels",
    "high heels": "heels",
    "pumps": "heels",
    "stilettos": "heels",

    # loafers
    "loafer": "loafers",
    "loafers": "loafers",

    # slippers
    "slipper": "slippers",
    "slippers": "slippers",

    # --- ACCESSORIES ---
    "cap": "accessories",
    "hat": "accessories",
    "beanie": "accessories",
    "belt": "accessories",
    "scarf": "accessories",
    "watch": "accessories",
    "bag": "accessories",
    "backpack": "accessories",
    "purse": "accessories",
    "handbag": "accessories",
    "sunglasses": "accessories",
}

def normalize_token(value) -> str:
    text = str(value or "").strip().lower().replace("_", " ").replace("-", " ")
    return " ".join(text.split())


def _expand_alias_map(alias_map: dict) -> dict:
    expanded = {}
    for raw, canonical in alias_map.items():
        key = normalize_token(raw)
        target = normalize_token(canonical)
        if not key or not target:
            continue
        expanded[key] = target
        expanded[key.replace(" ", "")] = target
    return expanded


COLOR_ALIAS_LOOKUP = _expand_alias_map(COLOR_ALIASES)
SUBCATEGORY_ALIAS_LOOKUP = _expand_alias_map(SUBCATEGORY_ALIASES)


def normalize_color_label(value) -> Optional[str]:
    token = normalize_token(value)
    if not token:
        return None
    if token in {"unknown", "n/a", "na", "none"}:
        return "Unknown"
    compact = token.replace(" ", "")
    mapped = COLOR_ALIAS_LOOKUP.get(token) or COLOR_ALIAS_LOOKUP.get(compact)
    return mapped or token


def normalize_subcategory_label(value) -> Optional[str]:
    token = normalize_token(value)
    if not token:
        return None
    compact = token.replace(" ", "")
    mapped = SUBCATEGORY_ALIAS_LOOKUP.get(token) or SUBCATEGORY_ALIAS_LOOKUP.get(compact) or token
    return to_display_label(mapped)


def coerce_temperature_label(value, allow_unknown: bool = False) -> Optional[str]:
    token = normalize_token(value)
    if not token:
        return None
    token = TEMPERATURE_ALIASES.get(token, token)
    if token in ALLOWED_TEMPERATURES:
        return token
    return token if allow_unknown else None


def coerce_weather_label(value, allow_unknown: bool = False) -> Optional[str]:
    token = normalize_token(value)
    if not token:
        return None
    token = WEATHER_ALIASES.get(token, token)
    if token in ALLOWED_WEATHER:
        return token
    return token if allow_unknown else None


def _parse_attribute_string(raw: str) -> List[str]:
    text = (raw or "").strip()
    if not text:
        return []

    if text.startswith("[") and text.endswith("]"):
        try:
            decoded = json.loads(text)
            if isinstance(decoded, list):
                return [str(item) for item in decoded]
        except json.JSONDecodeError:
            pass

    return [segment for segment in re.split(r"[,\n;]+", text) if segment]


def normalize_attributes(raw_attributes) -> List[str]:
    if raw_attributes is None:
        return []

    queue: List = []
    if isinstance(raw_attributes, (list, tuple, set)):
        queue.extend(raw_attributes)
    elif isinstance(raw_attributes, str):
        queue.extend(_parse_attribute_string(raw_attributes))
    else:
        queue.append(raw_attributes)

    normalized: List[str] = []
    seen = set()

    while queue:
        candidate = queue.pop(0)

        if isinstance(candidate, (list, tuple, set)):
            queue.extend(candidate)
            continue

        if isinstance(candidate, str):
            parts = _parse_attribute_string(candidate)
            if len(parts) > 1:
                queue.extend(parts)
                continue

        token = normalize_token(candidate)
        if not token or token in seen:
            continue
        seen.add(token)
        normalized.append(token)

    return normalized


def to_display_label(value: Optional[str]) -> Optional[str]:
    token = normalize_token(value)
    if not token:
        return None
    return " ".join(part.capitalize() for part in token.split())
