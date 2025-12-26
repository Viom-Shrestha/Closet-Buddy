import cv2
import numpy as np
from sklearn.cluster import KMeans
import webcolors

import webcolors

def get_color_name(rgb):
    """Finds the closest human-readable name for an RGB value."""
    try:
        # Try to find an exact match
        return webcolors.rgb_to_name(rgb)
    except ValueError:
        # Calculate the "closest" color
        min_colors = {}
        
        # In newer webcolors, use CSS3_NAMES_TO_HEX or a similar mapping
        # Let's use the most compatible way:
        for name in webcolors.names():
            color_rgb = webcolors.name_to_rgb(name)
            rd = (color_rgb.red - rgb[0]) ** 2
            gd = (color_rgb.green - rgb[1]) ** 2
            bd = (color_rgb.blue - rgb[2]) ** 2
            min_colors[(rd + gd + bd)] = name
            
        return min_colors[min(min_colors.keys())]

def extract_colors_with_names(image_path):
    # 1. Load image with Alpha Channel
    img = cv2.imread(image_path, cv2.IMREAD_UNCHANGED)
    if img is None:
        print(f"CRITICAL: OpenCV could not read file at {image_path}")
        return {"dominant_color": "Unknown", "secondary_color": "Unknown"}

    # 2. Extract non-transparent pixels
    if img.shape[2] == 4:
        # Get pixels where alpha > 0
        mask = img[:, :, 3] > 0
        pixels = img[mask][:, :3] 
    else:
        pixels = img.reshape(-1, 3)

    if len(pixels) < 10: # If the image is empty or tiny
        return {"dominant_color": "Empty", "secondary_color": "Empty"}

    # 3. K-Means clustering (Find top 2 colors)
    pixels = cv2.cvtColor(np.array([pixels]), cv2.COLOR_BGR2RGB)[0]
    kmeans = KMeans(n_clusters=2, n_init=10)
    kmeans.fit(pixels)
    
    colors = kmeans.cluster_centers_.astype(int)
    
    return {
        "dominant_color": get_color_name(colors[0]),
        "secondary_color": get_color_name(colors[1]) if len(colors) > 1 else None
    }