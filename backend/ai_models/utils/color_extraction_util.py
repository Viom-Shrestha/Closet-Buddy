import cv2
import numpy as np
import webcolors
from difflib import SequenceMatcher
from sklearn.cluster import KMeans

UNKNOWN_RESULT = {"dominant_color": "Unknown", "secondary_color": "Unknown"}
MAX_SAMPLE_PIXELS = 20000

# ─── Shared family vocabulary for extraction + scoring alignment ─────────────
COLOR_FAMILIES = {
    # Neutrals
    "white": [
        "white", "cream", "ivory", "off-white", "snow", "chalk",
        "pearl", "alabaster", "eggshell", "linen", "porcelain",
    ],
    "black": [
        "black", "charcoal", "onyx", "jet", "ebony", "obsidian",
        "carbon", "midnight black", "matte black",
    ],
    "grey": [
        "gray", "grey", "silver", "slate", "ash", "pewter",
        "graphite", "steel", "dove grey", "cool grey", "warm grey",
        "stone", "cement", "smoke",
    ],
    "navy": [
        "navy", "midnight", "dark blue", "navy blue", "midnight blue",
        "deep navy", "indigo navy",
    ],
    "beige": [
        "beige", "tan", "sand", "camel", "khaki", "taupe",
        "wheat", "oat", "ecru", "buff", "parchment", "latte",
        "biscuit", "almond", "sesame", "flax",
    ],
    "brown": [
        "brown", "chocolate", "espresso", "cognac", "rust",
        "chestnut", "mahogany", "walnut", "mocha", "toffee",
        "sienna", "umber", "hazel", "bark", "cinnamon",
        "tobacco", "saddle", "pecan", "hickory",
    ],
    # Blues
    "blue": [
        "blue", "cobalt", "sky blue", "denim", "powder blue",
        "cornflower", "periwinkle", "cerulean", "azure",
        "electric blue", "sapphire", "royal blue", "steel blue",
        "baby blue", "ice blue", "french blue", "china blue",
    ],
    "indigo": ["indigo", "deep indigo", "violet blue", "blue violet", "dark indigo"],
    # Greens
    "green": [
        "green", "forest", "emerald", "bottle green", "hunter green",
        "racing green", "pine", "fern", "moss", "jungle",
    ],
    "olive": [
        "olive", "olive green", "dark olive", "military green",
        "army green", "khaki green", "swamp", "avocado",
    ],
    "sage": [
        "sage", "sage green", "muted green", "dusty green",
        "eucalyptus", "celadon", "seafoam", "pale green",
        "mint", "tea green", "pistachio",
    ],
    "teal": [
        "teal", "teal green", "teal blue", "dark teal",
        "petrol", "duck egg", "peacock", "lagoon",
    ],
    "turquoise": ["turquoise", "aqua", "cyan", "aquamarine", "sea green", "water green"],
    # Reds & Pinks
    "red": [
        "red", "crimson", "scarlet", "fire red", "tomato",
        "cherry", "apple red", "candy red", "vermillion",
    ],
    "burgundy": [
        "burgundy", "wine", "bordeaux", "maroon", "oxblood",
        "dark red", "deep red", "merlot", "claret", "garnet",
        "cabernet", "port", "aubergine red",
    ],
    "pink": [
        "pink", "hot pink", "fuchsia", "magenta", "flamingo",
        "bubblegum", "candy pink", "bright pink", "neon pink",
    ],
    "blush": [
        "blush", "rose", "mauve", "dusty pink", "dusty rose",
        "pale pink", "ballet pink", "petal", "powder pink",
        "rose quartz", "antique rose", "tea rose",
    ],
    "coral": [
        "coral", "peach", "salmon", "terracotta", "apricot",
        "melon", "clay", "burnt sienna pink", "adobe",
    ],
    # Yellows & Oranges
    "yellow": [
        "yellow", "bright yellow", "lemon", "canary", "sunshine",
        "neon yellow", "chartreuse yellow",
    ],
    "mustard": [
        "mustard", "gold", "amber", "honey", "ochre", "saffron",
        "turmeric", "dijon", "straw", "goldenrod", "wheat gold",
    ],
    "orange": [
        "orange", "burnt orange", "tangerine", "mandarin",
        "pumpkin", "rust orange", "amber orange", "saffron orange",
    ],
    # Purples
    "purple": [
        "purple", "violet", "plum", "aubergine", "eggplant",
        "dark purple", "deep purple", "grape", "amethyst",
        "mulberry", "boysenberry", "raisin",
    ],
    "lavender": [
        "lavender", "lilac", "periwinkle", "wisteria", "orchid",
        "thistle", "soft purple", "pale purple", "violet grey",
        "dusty purple", "pale violet", "pale lavender",
    ],
}


def _normalize_name_token(value):
    text = str(value or "").strip().lower().replace("_", " ").replace("-", " ")
    return " ".join(text.split())


COLOR_ALIAS_TO_FAMILY = {}
for _family, _members in COLOR_FAMILIES.items():
    for _name in [_family] + list(_members):
        _norm = _normalize_name_token(_name)
        if not _norm:
            continue
        COLOR_ALIAS_TO_FAMILY[_norm] = _family
        COLOR_ALIAS_TO_FAMILY[_norm.replace(" ", "")] = _family


def _family_from_name(name):
    normalized = _normalize_name_token(name)
    if not normalized:
        return None
    compact = normalized.replace(" ", "")

    if normalized in COLOR_ALIAS_TO_FAMILY:
        return COLOR_ALIAS_TO_FAMILY[normalized]
    if compact in COLOR_ALIAS_TO_FAMILY:
        return COLOR_ALIAS_TO_FAMILY[compact]

    for family in COLOR_FAMILIES:
        if family in normalized or normalized in family:
            return family

    return None


def _best_alias_for_family(family, source_name):
    members = [_normalize_name_token(member) for member in COLOR_FAMILIES.get(family, [])]
    candidates = [member for member in members if member]
    if not candidates:
        return family

    normalized_source = _normalize_name_token(source_name)
    compact_source = normalized_source.replace(" ", "")

    for candidate in candidates:
        if candidate == normalized_source:
            return candidate
        if candidate.replace(" ", "") == compact_source:
            return candidate

    source_tokens = set(normalized_source.split())

    def _candidate_score(candidate):
        candidate_tokens = set(candidate.split())
        overlap = 0.0
        union = source_tokens | candidate_tokens
        if union:
            overlap = len(source_tokens & candidate_tokens) / len(union)
        compact_ratio = SequenceMatcher(
            None,
            compact_source,
            candidate.replace(" ", ""),
        ).ratio()
        contains_bonus = 0.05 if (
            candidate in normalized_source or normalized_source in candidate
        ) else 0.0
        return (0.6 * overlap) + (0.4 * compact_ratio) + contains_bonus

    return max(candidates, key=_candidate_score)


def _closest_css_name(rgb):
    rgb_tuple = (int(rgb[0]), int(rgb[1]), int(rgb[2]))

    # Prefer exact CSS color match when available.
    try:
        return webcolors.rgb_to_name(rgb_tuple, spec="css3")
    except ValueError:
        pass

    nearest_name = "unknown"
    nearest_distance = float("inf")

    for name in webcolors.names(spec="css3"):
        named = webcolors.name_to_rgb(name, spec="css3")
        distance = (
            (named.red - rgb_tuple[0]) ** 2
            + (named.green - rgb_tuple[1]) ** 2
            + (named.blue - rgb_tuple[2]) ** 2
        )
        if distance < nearest_distance:
            nearest_distance = distance
            nearest_name = name

    return nearest_name


def _normalize_color_name(rgb):
    r, g, b = int(rgb[0]), int(rgb[1]), int(rgb[2])
    max_c = max(r, g, b)
    min_c = min(r, g, b)
    spread = max_c - min_c

    # Handle neutrals explicitly before CSS nearest-name matching.
    if max_c < 40:
        return "black"
    if min_c > 225 and spread < 20:
        return "white"
    if spread < 15:
        return "grey"

    css_name = _closest_css_name((r, g, b))
    family = _family_from_name(css_name)
    if family:
        return _best_alias_for_family(family, css_name)

    return _normalize_name_token(css_name)


def _extract_rgb_pixels(img):
    if img is None:
        return None

    if img.ndim == 2:
        img = cv2.cvtColor(img, cv2.COLOR_GRAY2BGR)

    if img.ndim != 3:
        return None

    if img.shape[2] == 4:
        alpha = img[:, :, 3]
        # Ignore near-transparent pixels from PNG backgrounds.
        mask = alpha > 10
        bgr = img[:, :, :3]
        pixels = bgr[mask]
    else:
        pixels = img.reshape(-1, 3)

    if pixels is None or len(pixels) == 0:
        return None

    # Drop near-black pixels that often come from segmentation artifacts.
    valid = np.any(pixels > 8, axis=1)
    pixels = pixels[valid]

    if len(pixels) == 0:
        return None

    if len(pixels) > MAX_SAMPLE_PIXELS:
        rng = np.random.default_rng(42)
        idx = rng.choice(len(pixels), MAX_SAMPLE_PIXELS, replace=False)
        pixels = pixels[idx]

    return cv2.cvtColor(np.array([pixels]), cv2.COLOR_BGR2RGB)[0]


def extract_colors_with_names(image_path):
    img = cv2.imread(image_path, cv2.IMREAD_UNCHANGED)
    rgb_pixels = _extract_rgb_pixels(img)

    if rgb_pixels is None or len(rgb_pixels) < 10:
        return UNKNOWN_RESULT.copy()

    # Use at most 2 clusters and keep deterministic behavior.
    n_clusters = 2 if len(rgb_pixels) >= 30 else 1

    try:
        kmeans = KMeans(n_clusters=n_clusters, n_init=10, random_state=42)
        labels = kmeans.fit_predict(rgb_pixels)
        centers = kmeans.cluster_centers_.astype(int)
    except Exception:
        return UNKNOWN_RESULT.copy()

    counts = np.bincount(labels, minlength=n_clusters)
    ordered_idx = np.argsort(-counts)
    ordered_colors = centers[ordered_idx]

    dominant_color = _normalize_color_name(ordered_colors[0])
    secondary_color = (
        _normalize_color_name(ordered_colors[1])
        if len(ordered_colors) > 1
        else "Unknown"
    )

    return {
        "dominant_color": dominant_color,
        "secondary_color": secondary_color,
    }
