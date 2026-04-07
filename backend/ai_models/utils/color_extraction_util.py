import colorsys
import cv2
import numpy as np
from sklearn.cluster import KMeans

UNKNOWN_RESULT = {"dominant_color": "Unknown", "secondary_color": "Unknown"}
MAX_SAMPLE_PIXELS = 20000

# Expanded, canonical color families aligned with recommendation scoring.
COLOR_FAMILIES = {
    "black": [(8, 8, 8), (25, 25, 25)],
    "white": [(245, 245, 245), (255, 255, 255)],
    "grey": [(95, 95, 95), (128, 128, 128), (160, 160, 160)],
    "navy": [(18, 35, 64), (23, 41, 84), (35, 53, 95)],
    "beige": [(210, 185, 150), (219, 198, 166), (240, 230, 205)],
    "brown": [(92, 58, 32), (120, 72, 38), (160, 98, 58)],
    "blue": [(35, 75, 165), (44, 106, 204), (70, 150, 220)],
    "indigo": [(66, 47, 125), (75, 0, 130), (90, 70, 170)],
    "green": [(28, 110, 56), (36, 130, 70), (64, 160, 90)],
    "olive": [(96, 105, 45), (112, 120, 45), (132, 140, 55)],
    "sage": [(136, 164, 126), (154, 178, 142), (167, 188, 154)],
    "teal": [(18, 110, 114), (26, 128, 124), (34, 145, 140)],
    "turquoise": [(48, 190, 180), (64, 206, 192), (80, 220, 206)],
    "red": [(170, 38, 42), (198, 48, 49), (222, 55, 60)],
    "burgundy": [(95, 22, 36), (110, 30, 46), (128, 36, 52)],
    "pink": [(214, 112, 168), (236, 132, 170), (244, 95, 160)],
    "blush": [(220, 164, 176), (230, 176, 186), (240, 195, 204)],
    "coral": [(236, 133, 108), (242, 120, 92), (248, 142, 114)],
    "yellow": [(232, 206, 35), (243, 219, 54), (252, 232, 88)],
    "mustard": [(171, 129, 25), (186, 144, 34), (198, 153, 45)],
    "orange": [(218, 118, 28), (232, 133, 45), (245, 145, 60)],
    "purple": [(118, 58, 156), (130, 70, 170), (148, 82, 190)],
    "lavender": [(182, 156, 212), (196, 170, 224), (210, 188, 232)],
}

def _closest_color(rgb):
    r, g, b = rgb
    min_dist = float("inf")
    best_color = "grey"

    for name, values in COLOR_FAMILIES.items():
        for cr, cg, cb in values:
            dist = (r - cr) ** 2 + (g - cg) ** 2 + (b - cb) ** 2
            if dist < min_dist:
                min_dist = dist
                best_color = name

    return best_color


def _normalize_color(rgb):
    r, g, b = (int(rgb[0]), int(rgb[1]), int(rgb[2]))
    max_c = max(r, g, b)
    min_c = min(r, g, b)
    chroma = max_c - min_c

    # Fast neutral checks.
    if max_c < 35:
        return "black"
    if min_c > 225 and chroma < 22:
        return "white"
    if chroma < 18:
        if max_c < 65:
            return "black"
        if min_c > 205:
            return "white"
        return "grey"

    h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
    h_deg = h * 360.0

    # Keep a few simple HSV gates to avoid dark/pastel colors collapsing.
    if v < 0.30 and 205 <= h_deg <= 255 and s >= 0.20:
        return "navy"
    if v < 0.48 and (h_deg >= 334 or h_deg <= 14) and s >= 0.28:
        return "burgundy"
    if 18 <= h_deg <= 45 and v < 0.65 and s >= 0.20:
        return "brown"
    if 35 <= h_deg <= 58 and v >= 0.62 and s <= 0.38:
        return "beige"
    if 42 <= h_deg <= 64 and 0.32 <= v <= 0.78 and s >= 0.34:
        return "mustard"
    if 60 <= h_deg <= 95 and v <= 0.62 and s >= 0.22:
        return "olive"
    if 80 <= h_deg <= 150 and v >= 0.45 and s <= 0.35:
        return "sage"
    if (h_deg >= 336 or h_deg <= 18) and v >= 0.64 and s <= 0.36:
        return "blush"
    if 252 <= h_deg <= 305 and v >= 0.56 and s <= 0.36:
        return "lavender"
    if 165 <= h_deg <= 198 and s >= 0.34:
        return "teal" if v < 0.68 else "turquoise"
    if 8 <= h_deg <= 24 and v >= 0.62 and s >= 0.34:
        return "coral"

    return _closest_color((r, g, b))


def _extract_pixels(img):
    if img is None:
        return None

    if img.ndim == 2:
        img = cv2.cvtColor(img, cv2.COLOR_GRAY2BGR)

    if img.shape[2] == 4:  # RGBA
        alpha = img[:, :, 3]
        mask = alpha > 10
        pixels = img[:, :, :3][mask]
    else:
        pixels = img.reshape(-1, 3)

    if len(pixels) == 0:
        return None

    # Remove near-black noise
    pixels = pixels[np.any(pixels > 8, axis=1)]

    if len(pixels) == 0:
        return None

    # Sampling for speed
    if len(pixels) > MAX_SAMPLE_PIXELS:
        idx = np.random.choice(len(pixels), MAX_SAMPLE_PIXELS, replace=False)
        pixels = pixels[idx]

    return cv2.cvtColor(np.array([pixels]), cv2.COLOR_BGR2RGB)[0]


def extract_colors_with_names(image_path):
    img = cv2.imread(image_path, cv2.IMREAD_UNCHANGED)
    pixels = _extract_pixels(img)

    if pixels is None or len(pixels) < 10:
        return UNKNOWN_RESULT.copy()

    n_clusters = 2 if len(pixels) >= 30 else 1

    try:
        kmeans = KMeans(n_clusters=n_clusters, n_init=10, random_state=42)
        labels = kmeans.fit_predict(pixels)
        centers = kmeans.cluster_centers_.astype(int)
    except Exception:
        return UNKNOWN_RESULT.copy()

    counts = np.bincount(labels)
    sorted_idx = np.argsort(-counts)

    dominant = _normalize_color(centers[sorted_idx[0]])
    secondary = (
        _normalize_color(centers[sorted_idx[1]])
        if len(sorted_idx) > 1 else "Unknown"
    )
    if secondary == dominant:
        secondary = "Unknown"

    return {
        "dominant_color": dominant,
        "secondary_color": secondary,
    }
