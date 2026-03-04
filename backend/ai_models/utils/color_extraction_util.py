import cv2
import numpy as np
import webcolors
from sklearn.cluster import KMeans

UNKNOWN_RESULT = {"dominant_color": "Unknown", "secondary_color": "Unknown"}
MAX_SAMPLE_PIXELS = 20000


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
        return "gray"

    return _closest_css_name((r, g, b))


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
