import logging
from typing import Dict, List, Optional

from ..models import ClothingItem
from ..metadata_normalization import (
    coerce_temperature_label,
    coerce_weather_label,
    normalize_attributes,
)
from . import clip_utils
from .filters import (
    COLD_SIGNALS,
    HUMID_SIGNALS,
    RAIN_SIGNALS,
    SNOW_REQUIRED,
    WIND_SIGNALS,
    WARM_SIGNALS,
    attr_set,
    canonical_occasion,
    has_precipitation_profile,
    is_outerwear,
    item_occasion_signals,
)

LOGGER = logging.getLogger(__name__)


def _clamp(value: float, min_value: float = 0.0, max_value: float = 1.0) -> float:
    return max(min(value, max_value), min_value)


# ─── Shared prompt builders ───────────────────────────────────────────────────

def build_recommendation_prompt(
    user_prompt: Optional[str], occasion: Optional[str], weather: Dict
) -> str:
    temperature = (weather.get("temperature") or "").strip()
    condition = (weather.get("weather") or "").strip()
    parts: List[str] = []
    if user_prompt:
        parts.append(user_prompt.strip())
        if occasion:
            parts.append(occasion.strip())
        if temperature:
            parts.append(temperature)
        if condition:
            parts.append(condition)
        return " ".join([p for p in parts if p])
    weather_phrase = temperature or condition or "mild"
    if occasion:
        return f"a stylish {occasion.strip()} outfit for {weather_phrase} weather"
    return f"a stylish outfit for {weather_phrase} weather"


# Keep old name as alias so engine.py doesn't need changes immediately
build_prompt = build_recommendation_prompt


def _outfit_items(outfit: Dict) -> List[ClothingItem]:
    items = [outfit["topwear"], outfit["bottomwear"], outfit["shoes"]]
    if outfit.get("outerwear"):
        items.append(outfit["outerwear"])
    return items


def _clean_label(value: Optional[str]) -> str:
    return " ".join(str(value or "").strip().lower().replace("_", " ").replace("-", " ").split())


def build_rating_prompt(outfit: Dict) -> str:
    items = _outfit_items(outfit)
    occasions = [canonical_occasion(i.occasion) for i in items if i.occasion]
    occasions = [occasion for occasion in occasions if occasion]
    most_common = max(set(occasions), key=occasions.count) if occasions else ""

    garments: List[str] = []
    for item in items:
        sub = _clean_label(item.subcategory)
        cat = _clean_label(item.category)
        label = sub or cat
        if label and label not in garments:
            garments.append(label)

    colors: List[str] = []
    for item in items:
        color = _clean_label(getattr(item, "dominant_color", ""))
        if color and color != "unknown" and color not in colors:
            colors.append(color)

    parts = ["a cohesive stylish outfit"]
    if most_common:
        parts.append(f"for {most_common} occasions")
    if garments:
        parts.append(f"featuring {', '.join(garments[:4])}")
    if colors:
        parts.append(f"using {', '.join(colors[:4])} tones")
    return " ".join(parts)


# ─── Shared sub-scores ────────────────────────────────────────────────────────

def clip_score(outfit: Dict, text_prompt: str) -> float:
    try:
        text_embedding = clip_utils.get_text_embedding(text_prompt)
        if text_embedding is None:
            return 0.5

        item_scores: List[float] = []
        for item in _outfit_items(outfit):
            image_path = getattr(getattr(item, "image", None), "path", "")
            image_embedding = clip_utils.get_image_embedding(image_path)
            if image_embedding is not None:
                item_scores.append(clip_utils.cosine_similarity(image_embedding, text_embedding))

        if not item_scores:
            LOGGER.warning(
                "clip_score produced no image embeddings for outfit (top=%s, bottom=%s, shoes=%s)",
                getattr(outfit.get("topwear"), "id", None),
                getattr(outfit.get("bottomwear"), "id", None),
                getattr(outfit.get("shoes"), "id", None),
            )
            return 0.5

        mean_score = sum(item_scores) / len(item_scores)
        min_score = min(item_scores)
        return _clamp((0.75 * mean_score) + (0.25 * min_score))
    except Exception as exc:
        LOGGER.warning(
            "clip_score failed for outfit (top=%s, bottom=%s, shoes=%s): %s",
            getattr(outfit.get("topwear"), "id", None),
            getattr(outfit.get("bottomwear"), "id", None),
            getattr(outfit.get("shoes"), "id", None),
            exc,
        )
        return 0.5


# ─── Color family definitions ─────────────────────────────────────────────────
COLOR_FAMILIES: Dict[str, List[str]] = {
    # Neutrals
    "white":     ["white", "cream", "ivory", "off-white", "snow", "chalk",
                    "pearl", "alabaster", "eggshell", "linen", "porcelain"],
    "black":     ["black", "charcoal", "onyx", "jet", "ebony", "obsidian",
                    "carbon", "midnight black", "matte black"],
    "grey":      ["gray", "grey", "silver", "slate", "ash", "pewter",
                    "graphite", "steel", "dove grey", "cool grey", "warm grey",
                    "stone", "cement", "smoke"],
    "navy":      ["navy", "midnight", "dark blue", "navy blue", "midnight blue",
                    "deep navy", "indigo navy"],
    "beige":     ["beige", "tan", "sand", "camel", "khaki", "taupe",
                    "wheat", "oat", "ecru", "buff", "parchment", "latte",
                    "biscuit", "almond", "sesame", "flax"],
    "brown":     ["brown", "chocolate", "espresso", "cognac", "rust",
                    "chestnut", "mahogany", "walnut", "mocha", "toffee",
                    "sienna", "umber", "hazel", "bark", "cinnamon",
                    "tobacco", "saddle", "pecan", "hickory"],

    # Blues
    "blue":      ["blue", "cobalt", "sky blue", "denim", "powder blue",
                    "cornflower", "periwinkle", "cerulean", "azure",
                    "electric blue", "sapphire", "royal blue", "steel blue",
                    "baby blue", "ice blue", "french blue", "china blue"],
    "indigo":    ["indigo", "deep indigo", "violet blue", "blue violet",
                    "dark indigo"],

    # Greens
    "green":     ["green", "forest", "emerald", "bottle green", "hunter green",
                    "racing green", "pine", "fern", "moss", "jungle"],
    "olive":     ["olive", "olive green", "dark olive", "military green",
                    "army green", "khaki green", "swamp", "avocado"],
    "sage":      ["sage", "sage green", "muted green", "dusty green",
                    "eucalyptus", "celadon", "seafoam", "pale green",
                    "mint", "tea green", "pistachio"],
    "teal":      ["teal", "teal green", "teal blue", "dark teal",
                    "petrol", "duck egg", "peacock", "lagoon"],
    "turquoise": ["turquoise", "aqua", "cyan", "aquamarine", "sea green",
                    "water green"],

    # Reds & Pinks
    "red":       ["red", "crimson", "scarlet", "fire red", "tomato",
                    "cherry", "apple red", "candy red", "vermillion"],
    "burgundy":  ["burgundy", "wine", "bordeaux", "maroon", "oxblood",
                    "dark red", "deep red", "merlot", "claret", "garnet",
                    "cabernet", "port", "aubergine red"],
    "pink":      ["pink", "hot pink", "fuchsia", "magenta", "flamingo",
                    "bubblegum", "candy pink", "bright pink", "neon pink"],
    "blush":     ["blush", "rose", "mauve", "dusty pink", "dusty rose",
                    "pale pink", "ballet pink", "petal", "powder pink",
                    "rose quartz", "antique rose", "tea rose"],
    "coral":     ["coral", "peach", "salmon", "terracotta", "apricot",
                    "melon", "clay", "burnt sienna pink", "adobe"],

    # Yellows & Oranges
    "yellow":    ["yellow", "bright yellow", "lemon", "canary", "sunshine",
                    "neon yellow", "chartreuse yellow"],
    "mustard":   ["mustard", "gold", "amber", "honey", "ochre", "saffron",
                    "turmeric", "dijon", "straw", "goldenrod", "wheat gold"],
    "orange":    ["orange", "burnt orange", "tangerine", "mandarin",
                    "pumpkin", "rust orange", "amber orange", "saffron orange"],

    # Purples
    "purple":    ["purple", "violet", "plum", "aubergine", "eggplant",
                    "dark purple", "deep purple", "grape", "amethyst",
                    "mulberry", "boysenberry", "raisin"],
    "lavender":  ["lavender", "lilac", "periwinkle", "wisteria", "orchid",
                    "thistle", "soft purple", "pale purple", "violet grey",
                    "dusty purple", "pale violet", "pale lavender"],
}

NEUTRAL_FAMILIES = {"white", "black", "grey", "navy", "beige", "brown"}

WARM_FAMILIES = {
    "red", "burgundy", "orange", "coral", "yellow",
    "mustard", "brown", "pink", "blush",
}
COOL_FAMILIES = {
    "blue", "indigo", "navy", "green", "olive", "sage",
    "teal", "turquoise", "purple", "lavender", "grey",
}
# Families that sit between warm and cool — pair with either
NEUTRAL_TEMP_FAMILIES = {"white", "black", "beige"}

# ─── Known good pairings (family-level) ───────────────────────────────────────
GOOD_PAIRINGS: set[frozenset[str]] = {
    # Classic neutrals
    frozenset(["black", "white"]),
    frozenset(["black", "grey"]),
    frozenset(["black", "beige"]),
    frozenset(["black", "navy"]),
    frozenset(["grey", "white"]),
    frozenset(["grey", "beige"]),
    frozenset(["navy", "white"]),
    frozenset(["navy", "beige"]),
    frozenset(["navy", "grey"]),
    frozenset(["beige", "white"]),
    frozenset(["brown", "beige"]),
    frozenset(["brown", "white"]),
    frozenset(["brown", "cream"]),  # cream maps to white family

    # Neutral + single accent (timeless combos)
    frozenset(["black", "red"]),
    frozenset(["black", "burgundy"]),
    frozenset(["black", "blush"]),
    frozenset(["black", "teal"]),
    frozenset(["black", "mustard"]),
    frozenset(["black", "olive"]),
    frozenset(["black", "sage"]),
    frozenset(["black", "lavender"]),
    frozenset(["navy", "red"]),
    frozenset(["navy", "mustard"]),
    frozenset(["navy", "olive"]),
    frozenset(["navy", "teal"]),
    frozenset(["navy", "coral"]),
    frozenset(["navy", "blush"]),
    frozenset(["navy", "burgundy"]),
    frozenset(["grey", "blue"]),
    frozenset(["grey", "blush"]),
    frozenset(["grey", "burgundy"]),
    frozenset(["grey", "mustard"]),
    frozenset(["grey", "teal"]),
    frozenset(["grey", "lavender"]),
    frozenset(["grey", "olive"]),
    frozenset(["grey", "sage"]),
    frozenset(["beige", "olive"]),
    frozenset(["beige", "brown"]),
    frozenset(["beige", "teal"]),
    frozenset(["beige", "burgundy"]),
    frozenset(["beige", "sage"]),
    frozenset(["beige", "mustard"]),
    frozenset(["beige", "blush"]),
    frozenset(["beige", "coral"]),
    frozenset(["white", "blue"]),
    frozenset(["white", "red"]),
    frozenset(["white", "olive"]),
    frozenset(["white", "teal"]),
    frozenset(["white", "sage"]),
    frozenset(["white", "blush"]),
    frozenset(["white", "lavender"]),
    frozenset(["white", "mustard"]),
    frozenset(["brown", "teal"]),
    frozenset(["brown", "olive"]),
    frozenset(["brown", "mustard"]),
    frozenset(["brown", "sage"]),
    frozenset(["brown", "burgundy"]),
    frozenset(["brown", "coral"]),
    frozenset(["brown", "blush"]),

    # Accent + accent (analogous — close on the color wheel)
    frozenset(["blue", "teal"]),
    frozenset(["blue", "indigo"]),
    frozenset(["blue", "purple"]),
    frozenset(["teal", "sage"]),
    frozenset(["teal", "olive"]),
    frozenset(["teal", "green"]),
    frozenset(["olive", "sage"]),
    frozenset(["olive", "mustard"]),
    frozenset(["olive", "brown"]),
    frozenset(["mustard", "orange"]),
    frozenset(["mustard", "coral"]),
    frozenset(["orange", "coral"]),
    frozenset(["coral", "blush"]),
    frozenset(["blush", "lavender"]),
    frozenset(["blush", "pink"]),
    frozenset(["pink", "purple"]),
    frozenset(["purple", "lavender"]),
    frozenset(["burgundy", "blush"]),
    frozenset(["burgundy", "brown"]),
    frozenset(["burgundy", "olive"]),
    frozenset(["red", "orange"]),

    # Complementary pairs (opposite on wheel — high contrast but intentional)
    frozenset(["blue", "orange"]),
    frozenset(["blue", "coral"]),
    frozenset(["blue", "mustard"]),
    frozenset(["teal", "coral"]),
    frozenset(["teal", "burgundy"]),
    frozenset(["purple", "mustard"]),
    frozenset(["purple", "olive"]),
    frozenset(["lavender", "mustard"]),
    frozenset(["green", "burgundy"]),
    frozenset(["olive", "burgundy"]),
    frozenset(["sage", "blush"]),
    frozenset(["sage", "burgundy"]),
    frozenset(["navy", "mustard"]),
    frozenset(["indigo", "coral"]),
    frozenset(["indigo", "mustard"]),
}

# ─── Known clashing pairings ──────────────────────────────────────────────────
BAD_PAIRINGS: set[frozenset[str]] = {
    frozenset(["red", "green"]),
    frozenset(["red", "orange"]),      # too close, fights itself
    frozenset(["red", "pink"]),
    frozenset(["red", "purple"]),
    frozenset(["orange", "purple"]),
    frozenset(["orange", "pink"]),
    frozenset(["yellow", "purple"]),
    frozenset(["yellow", "blue"]),     # garish unless very muted
    frozenset(["yellow", "red"]),
    frozenset(["yellow", "green"]),    # neon clash
    frozenset(["pink", "orange"]),
    frozenset(["pink", "red"]),
    frozenset(["burgundy", "navy"]),   # too similar in tone, muddies
    frozenset(["brown", "grey"]),      # warm + cool mud
    frozenset(["brown", "navy"]),
    frozenset(["teal", "purple"]),
    frozenset(["lavender", "teal"]),
    frozenset(["lavender", "orange"]),
    frozenset(["coral", "purple"]),
    frozenset(["coral", "red"]),
    frozenset(["indigo", "green"]),
    frozenset(["indigo", "teal"]),     # too similar, no contrast
    frozenset(["black", "brown"]),     # near-neutral clash — looks like a mistake
}


def _normalize_color_token(color: str) -> str:
    text = str(color or "").strip().lower().replace("_", " ").replace("-", " ")
    return " ".join(text.split())


COLOR_ALIAS_TO_FAMILY: Dict[str, str] = {}
for _family, _members in COLOR_FAMILIES.items():
    for _name in [_family] + list(_members):
        _normalized = _normalize_color_token(_name)
        if not _normalized:
            continue
        COLOR_ALIAS_TO_FAMILY[_normalized] = _family
        COLOR_ALIAS_TO_FAMILY[_normalized.replace(" ", "")] = _family


def _get_family(color: str) -> Optional[str]:
    normalized = _normalize_color_token(color)
    compact = normalized.replace(" ", "")
    if normalized in COLOR_ALIAS_TO_FAMILY:
        return COLOR_ALIAS_TO_FAMILY[normalized]
    if compact and compact in COLOR_ALIAS_TO_FAMILY:
        return COLOR_ALIAS_TO_FAMILY[compact]

    # Fuzzy fallback — partial match on family name
    for family in COLOR_FAMILIES:
        if family in normalized or normalized in family:
            return family
    return None


def _color_temp(family: str) -> str:
    if family in WARM_FAMILIES:
        return "warm"
    if family in COOL_FAMILIES:
        return "cool"
    if family in NEUTRAL_TEMP_FAMILIES:
        return "neutral"
    return "neutral"


def color_harmony_score(outfit: Dict) -> float:
    items = [outfit["topwear"], outfit["bottomwear"], outfit["shoes"]]
    if outfit.get("outerwear"):
        items.append(outfit["outerwear"])

    families: List[str] = []
    for item in items:
        if item.dominant_color:
            fam = _get_family(str(item.dominant_color))
            if fam:
                families.append(fam)

    if not families:
        return 0.5

    unique_families = list(dict.fromkeys(families))
    non_neutral = [f for f in unique_families if f not in NEUTRAL_FAMILIES]
    neutral_fams = [f for f in unique_families if f in NEUTRAL_FAMILIES]

    # ── Hard penalty for known clashing pairs ────────────────────────────────
    clash_penalty = 0.0
    for i in range(len(non_neutral)):
        for j in range(i + 1, len(non_neutral)):
            pair = frozenset([non_neutral[i], non_neutral[j]])
            if pair in BAD_PAIRINGS:
                clash_penalty += 0.25
    # Also check accent vs neutral clashes (e.g. brown + grey)
    for acc in non_neutral:
        for neu in neutral_fams:
            pair = frozenset([acc, neu])
            if pair in BAD_PAIRINGS:
                clash_penalty += 0.15

    # ── Base score by palette structure ──────────────────────────────────────
    if len(unique_families) == 1:
        # Monochromatic — always clean
        score = 0.82

    elif len(non_neutral) == 0:
        # All neutrals — safe and intentional if not too many
        score = 0.88 if len(unique_families) <= 3 else 0.72

    elif len(non_neutral) == 1:
        # Neutral-anchored with one accent — strongest classic pattern
        accent = non_neutral[0]
        best_neutral = neutral_fams[0] if neutral_fams else None
        pair = frozenset([accent, best_neutral]) if best_neutral else None
        if pair and pair in GOOD_PAIRINGS:
            score = 0.95
        else:
            score = 0.85

    elif len(non_neutral) == 2:
        pair = frozenset(non_neutral)
        if pair in GOOD_PAIRINGS:
            # Known good accent pairing
            score = 0.82
        else:
            # Check temperature relationship
            temps = [_color_temp(f) for f in non_neutral]
            if "neutral" in temps:
                score = 0.72
            elif len(set(temps)) == 1:
                # Same temperature family — analogous, more forgiving
                score = 0.68
            else:
                # Cross-temperature unknown pair — risky
                score = 0.55

    elif len(non_neutral) == 3:
        # Three accents — only works if they're all analogous
        pairs = [
            frozenset([non_neutral[i], non_neutral[j]])
            for i in range(len(non_neutral))
            for j in range(i + 1, len(non_neutral))
        ]
        good_count = sum(1 for pair in pairs if pair in GOOD_PAIRINGS)
        score = 0.60 if good_count == len(pairs) else 0.42

    else:
        # Four+ accent families — almost always too busy
        score = 0.28

    # ── Too many total families regardless of type ────────────────────────────
    if len(unique_families) > 5:
        score -= 0.12

    # ── Apply clash penalties ─────────────────────────────────────────────────
    score -= min(clash_penalty, 0.40)

    return _clamp(score)


# ─── Dress-level consistency (rating-only) ───────────────────────────────────

DRESS_LEVEL_TIERS = {
    "formal": {
        "formal", "office", "business", "professional",
        "corporate", "suit", "blazer", "gala", "wedding",
    },
    "smart_casual": {
        "date", "travel",
    },
    "casual": {
        "casual", "everyday", "street", "streetwear",
        "vintage", "beach", "home", "weekend", "relaxed",
    },
    "athletic": {
        "sport", "sporty", "workout", "gym",
        "active", "training", "fitness",
    },
    "evening": {
        "party", "date", "cocktail", "evening", "romantic",
    },
    "traditional": {"traditional"},
    "outdoor": {
        "outdoor", "hiking", "camping", "festival",
    },
}

def dress_level_consistency_score(outfit: Dict) -> float:
    items = [outfit["topwear"], outfit["bottomwear"], outfit["shoes"]]
    if outfit.get("outerwear"):
        items.append(outfit["outerwear"])

    def get_tier(item: ClothingItem) -> Optional[str]:
        occ = canonical_occasion(item.occasion)
        occasion_signals = item_occasion_signals(item)

        # Check occasion field against tier keywords.
        for tier, keywords in DRESS_LEVEL_TIERS.items():
            if occ in keywords:
                return tier
            if occasion_signals & keywords:
                return tier

        # Fall back to raw attributes for non-occasion style cues.
        raw_attrs = set(normalize_attributes(item.attributes or []))
        for tier, keywords in DRESS_LEVEL_TIERS.items():
            if raw_attrs & keywords:
                return tier

        return None

    tiers = [get_tier(i) for i in items]
    tiers = [t for t in tiers if t is not None]
    if not tiers:
        return 0.5

    most_common = max(set(tiers), key=tiers.count)
    ratio = tiers.count(most_common) / len(tiers)
    return _clamp(ratio * 1.2 if ratio >= 0.5 else ratio * 0.6)


# ─── Weather-aware sub-scores (recommendation-only) ──────────────────────────

def _item_weather_score(item: ClothingItem, temperature: str, condition: str) -> float:
    score = 0.5

    # Primary: use classifier-backed weather labels when available.
    detected_temp = coerce_temperature_label(item.detected_temp, allow_unknown=True) or ""
    if detected_temp:
        temp_compatibility = {
            "freezing": {"freezing": 1.0, "cold": 0.7, "cool": 0.3, "warm": 0.1, "hot": 0.0},
            "cold": {"freezing": 0.8, "cold": 1.0, "cool": 0.6, "warm": 0.2, "hot": 0.0},
            "cool": {"freezing": 0.4, "cold": 0.7, "cool": 1.0, "warm": 0.7, "hot": 0.3},
            "warm": {"freezing": 0.0, "cold": 0.2, "cool": 0.6, "warm": 1.0, "hot": 0.8},
            "hot": {"freezing": 0.0, "cold": 0.0, "cool": 0.3, "warm": 0.8, "hot": 1.0},
        }
        score = temp_compatibility.get(temperature, {}).get(detected_temp, 0.5)
    else:
        # Fallback: attribute-based weather suitability.
        attrs = attr_set(item)
        if temperature in {"freezing", "cold"}:
            if attrs & COLD_SIGNALS:
                score += 0.3
            if attrs & WARM_SIGNALS:
                score -= 0.3
            if is_outerwear(item):
                score += 0.1
        elif temperature in {"warm", "hot"}:
            if attrs & WARM_SIGNALS:
                score += 0.3
            if attrs & COLD_SIGNALS:
                score -= 0.3
            if is_outerwear(item):
                score -= 0.2
        elif temperature == "cool":
            if attrs & COLD_SIGNALS:
                score += 0.1
            if attrs & WARM_SIGNALS:
                score += 0.05

    # Secondary: condition suitability, preferring classifier weather labels.
    detected_weather = coerce_weather_label(item.detected_weather, allow_unknown=True) or ""
    if detected_weather in {"rainy", "snowy"} and not has_precipitation_profile(item):
        # Legacy noisy labels on generic garments should not over-steer recommendations.
        detected_weather = ""
    if detected_weather:
        if condition == detected_weather:
            score = min(score + 0.1, 1.0)
        elif condition in {"rainy", "snowy"} and detected_weather == "dry":
            score = max(score - 0.15, 0.0)
    else:
        attrs = attr_set(item)
        if condition == "snowy":
            if attrs & SNOW_REQUIRED:
                score += 0.2
            elif attrs:
                score -= 0.2
            else:
                score -= 0.1
        if condition == "rainy":
            if attrs & RAIN_SIGNALS:
                score += 0.1
            elif attrs:
                score -= 0.05
        if condition == "windy":
            if attrs & WIND_SIGNALS:
                score += 0.1
            elif attrs & WARM_SIGNALS:  # Lightweight items suffer in wind.
                score -= 0.05
        if condition == "humid":
            if attrs & HUMID_SIGNALS:
                score += 0.1
            elif attrs & COLD_SIGNALS:  # Heavy fabrics in humidity are uncomfortable.
                score -= 0.08

    return _clamp(score)


def weather_score(outfit: Dict, weather: Dict) -> float:
    temperature = coerce_temperature_label(weather.get("temperature"), allow_unknown=True) or ""
    condition = coerce_weather_label(weather.get("weather"), allow_unknown=True) or ""
    items = [outfit["topwear"], outfit["bottomwear"], outfit["shoes"]]
    if outfit.get("outerwear"):
        items.append(outfit["outerwear"])
    scores = [_item_weather_score(item, temperature, condition) for item in items]
    return sum(scores) / max(len(scores), 1)


def item_occasion_score(item: ClothingItem, occasion: Optional[str]) -> float:
    if not occasion:
        return 0.5

    target = canonical_occasion(occasion)
    if not target:
        return 0.5
    item_occ = canonical_occasion(item.occasion)
    signals = item_occasion_signals(item)

    if item_occ == target:
        return 1.0
    if target in signals:
        return 0.85
    if not signals:
        return 0.45
    if item_occ and item_occ != target:
        return 0.2
    return 0.35


def item_context_score(item: ClothingItem, weather: Dict, occasion: Optional[str]) -> float:
    temperature = coerce_temperature_label(weather.get("temperature"), allow_unknown=True) or ""
    condition = coerce_weather_label(weather.get("weather"), allow_unknown=True) or ""

    weather_fit = _item_weather_score(item, temperature, condition)
    occasion_fit = item_occasion_score(item, occasion)

    # Phase-1 item vetting intentionally avoids CLIP and keeps focus on context relevance.
    return _clamp((0.65 * weather_fit) + (0.35 * occasion_fit))


def occasion_score(outfit: Dict, occasion: Optional[str]) -> float:
    if not occasion:
        return 0.5
    target = canonical_occasion(occasion)
    if not target:
        return 0.5
    items = _outfit_items(outfit)

    matches = 0
    for item in items:
        signals = item_occasion_signals(item)
        if target in signals:
            matches += 1

    ratio = matches / max(len(items), 1)
    # Require majority — partial matches penalized
    return _clamp(ratio * 1.2 if ratio >= 0.5 else ratio * 0.6)


def layering_score(outfit: Dict, weather: Dict) -> float:
    temperature = (weather.get("temperature") or "").strip().lower()
    has_outer = outfit.get("outerwear") is not None

    if temperature == "freezing":
        return 1.0 if has_outer else 0.2
    if temperature == "cold":
        return 0.9 if has_outer else 0.4
    if temperature in {"warm", "hot"}:
        return 0.2 if has_outer else 1.0
    if temperature == "cool":
        return 0.8 if has_outer else 0.6
    return 0.5


# ─── Recommendation scoring (weather-aware) ───────────────────────────────────

def final_score(
    outfit: Dict, weather: Dict, occasion: Optional[str], text_prompt: str
) -> float:
    clip        = clip_score(outfit, text_prompt)
    weather_fit = weather_score(outfit, weather)
    occasion_fit = occasion_score(outfit, occasion)
    color_fit   = color_harmony_score(outfit)
    layering_fit = layering_score(outfit, weather)

    return (
        (0.45 * clip)
        + (0.25 * weather_fit)
        + (0.15 * occasion_fit)
        + (0.10 * color_fit)
        + (0.05 * layering_fit)
    )


# ─── AI rating snapshot (style-only, no weather) ─────────────────────────────

def _palette_signature(outfit: Dict) -> str:
    families: List[str] = []
    for item in _outfit_items(outfit):
        fam = _get_family(str(getattr(item, "dominant_color", "") or ""))
        if fam and fam not in families:
            families.append(fam)

    if not families:
        return "mixed tones"
    if len(families) == 1:
        return f"{families[0]} tones"
    if len(families) == 2:
        return f"{families[0]} and {families[1]} tones"
    return f"{families[0]}, {families[1]}, and accent tones"


def _pairwise_image_cohesion_score(outfit: Dict) -> float:
    try:
        embeddings = []
        for item in _outfit_items(outfit):
            if not getattr(item, "image", None):
                continue
            embeddings.append(clip_utils.get_image_embedding(item.image.path))
        vectors = [vec for vec in embeddings if vec is not None]
        if len(vectors) < 2:
            return 0.5

        sims: List[float] = []
        for idx in range(len(vectors)):
            for jdx in range(idx + 1, len(vectors)):
                # Keep item-item cohesion on a simple normalized cosine scale.
                raw = float(vectors[idx].dot(vectors[jdx]))
                sims.append(_clamp((raw + 1.0) / 2.0))
        if not sims:
            return 0.5
        return _clamp(sum(sims) / len(sims))
    except Exception:
        return 0.5


def _item_style_tokens(item: ClothingItem) -> set:
    tokens = set()

    cat = _clean_label(item.category)
    if cat:
        tokens.add(f"cat:{cat}")

    sub = _clean_label(item.subcategory)
    if sub:
        tokens.add(f"sub:{sub}")

    occ = canonical_occasion(item.occasion)
    if occ:
        tokens.add(f"occ:{occ}")

    for attr in normalize_attributes(item.attributes or []):
        if attr:
            tokens.add(f"attr:{attr}")

    fam = _get_family(str(getattr(item, "dominant_color", "") or ""))
    if fam:
        tokens.add(f"color:{fam}")

    return tokens


def _attribute_cohesion_score(outfit: Dict) -> float:
    token_sets = [_item_style_tokens(item) for item in _outfit_items(outfit)]
    if len(token_sets) < 2:
        return 0.5

    sims: List[float] = []
    for idx in range(len(token_sets)):
        for jdx in range(idx + 1, len(token_sets)):
            left = token_sets[idx]
            right = token_sets[jdx]
            union = left | right
            jaccard = (len(left & right) / len(union)) if union else 0.5
            # Keep scale centered so sparse attributes do not collapse this score.
            sims.append(_clamp(0.35 + (0.65 * jaccard)))

    if not sims:
        return 0.5
    return _clamp(sum(sims) / len(sims))


def _composite_ai_cohesion_score(outfit: Dict, text_prompt: str) -> Dict[str, float]:
    prompt_alignment = clip_score(outfit, text_prompt)
    image_cohesion = _pairwise_image_cohesion_score(outfit)
    attribute_cohesion = _attribute_cohesion_score(outfit)
    composite = _clamp(
        (0.40 * prompt_alignment)
        + (0.40 * image_cohesion)
        + (0.20 * attribute_cohesion)
    )
    return {
        "composite": composite,
        "prompt_alignment": prompt_alignment,
        "image_cohesion": image_cohesion,
        "attribute_cohesion": attribute_cohesion,
    }


def _strength_reason(dimension: str, value: float, palette: str) -> str:
    if dimension == "cohesion":
        if value >= 0.80:
            return "The pieces match each other well and feel like one complete outfit."
        return "The overall style mostly works together, with room to make it feel tighter."

    if dimension == "color":
        if value >= 0.80:
            return f"The {palette} palette feels balanced and easy on the eyes."
        return f"The {palette} palette works fairly well overall."

    if value >= 0.80:
        return "Everything stays at a similar dress level, so the look feels intentional."
    return "Most pieces are close in dress level, but one item feels slightly off."


def _improvement_reason(dimension: str, value: float, palette: str) -> str:
    if dimension == "cohesion":
        return (
            "Main improvement: make the overall look feel more connected. "
            "Try swapping one piece so the style direction is more consistent."
        )
    if dimension == "color":
        return (
            f"Main improvement: color clarity in the {palette} palette. "
            "Use one dominant accent and let neutrals support it."
        )
    return (
        "Main improvement: keep the dress level consistent. "
        "Try to keep all pieces in a similar vibe (for example all casual or all dressy)."
    )


def ai_rating_snapshot(outfit: Dict) -> Dict:
    text_prompt = build_rating_prompt(outfit)
    cohesion_details = _composite_ai_cohesion_score(outfit, text_prompt)

    clip = cohesion_details["composite"]
    prompt_alignment = cohesion_details["prompt_alignment"]
    image_cohesion = cohesion_details["image_cohesion"]
    attribute_cohesion = cohesion_details["attribute_cohesion"]
    color = color_harmony_score(outfit)
    dress_level = dress_level_consistency_score(outfit)
    palette = _palette_signature(outfit)

    overall_raw = (0.45 * clip) + (0.35 * color) + (0.20 * dress_level)
    score = round(1 + (4 * overall_raw), 1)
    score = max(1.0, min(5.0, score))

    ranked = sorted(
        [("cohesion", clip), ("color", color), ("dress_level", dress_level)],
        key=lambda pair: pair[1],
        reverse=True,
    )
    strongest = ranked[0]
    second = ranked[1]
    weakest = ranked[-1]

    reasons = [
        _strength_reason(strongest[0], strongest[1], palette),
        _strength_reason(second[0], second[1], palette),
        _improvement_reason(weakest[0], weakest[1], palette),
    ]

    return {
        "ai_rating_score": score,
        "ai_rating_reasons": reasons,
        "ai_rating_breakdown": {
            # Keep legacy key name for client compatibility.
            "clip": round(clip, 4),
            "prompt_alignment": round(prompt_alignment, 4),
            "image_cohesion": round(image_cohesion, 4),
            "attribute_cohesion": round(attribute_cohesion, 4),
            "color_harmony": round(color, 4),
            "dress_level_consistency": round(dress_level, 4),
            # Keep legacy key name for client compatibility.
            "formality_consistency": round(dress_level, 4),
            # Legacy fallback key for older clients/tests.
            "neutral_weather_fit": round(dress_level, 4),
            "overall_raw": round(overall_raw, 4),
        },
    }
