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
}

OCCASION_ALIASES = {
    # Canonical labels from classifier.
    "casual": "casual",
    "formal": "formal",
    "office": "office",
    "party": "party",
    "date": "date",
    "traditional": "traditional",
    "sport": "sport",
    "home": "home",
    "travel": "travel",
    "beach": "beach",
    "street": "street",
    # Attribute/extractor variants.
    "sporty": "sport",
    "sports": "sport",
    "formal shoes": "formal",
    "casual shoes": "casual",
    "sports shoes": "sport",
    # User input aliases.
    "athletic": "sport",
    "gym": "sport",
    "active": "workout",
    "workout": "workout",
    "fitness": "workout",
    "work": "office",
    "workwear": "office",
    "business": "office",
    "business casual": "office",
    "professional": "office",
    "corporate": "office",
    "dating": "date",
    "date night": "date",
    "romantic": "date",
    "streetwear": "street",
    "street style": "street",
    "urban": "street",
    "night out": "party",
    "cocktail": "party",
    "going out": "party",
    "club": "party",
    "smart casual": "casual",
    "weekend": "casual",
    "everyday": "casual",
    "relaxed": "casual",
    "brunch": "casual",
    "outdoor": "outdoor",
    "hiking": "outdoor",
    "camping": "outdoor",
    "festival": "casual",
    "vacation": "beach",
    "black tie": "formal",
    "gala": "formal",
    "wedding": "formal",
    "any": "",
    "any occasion": "",
    "all": "",
    "all occasions": "",
}


def normalize_token(value) -> str:
    text = str(value or "").strip().lower().replace("_", " ").replace("-", " ")
    return " ".join(text.split())


def normalize_color_label(value) -> Optional[str]:
    token = normalize_token(value)
    if not token:
        return None
    if token == "unknown":
        return "Unknown"
    return token


def normalize_occasion_label(value) -> str:
    token = normalize_token(value)
    return OCCASION_ALIASES.get(token, token)


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
