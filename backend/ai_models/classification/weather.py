import torch
import clip
from PIL import Image
import numpy as np

# ─────────────────────────────────────────────
# Setup
# ─────────────────────────────────────────────

device = "cuda" if torch.cuda.is_available() else "cpu"
model, preprocess = clip.load("ViT-B/32", device=device)

# ─────────────────────────────────────────────
# Temperature Prompts (More granular)
# ─────────────────────────────────────────────

TEMPERATURE_PROMPTS = {
    "freezing": [
        "heavy winter coat for freezing weather",
        "snow jacket very thick clothing",
        "extreme cold outfit"
    ],
    "cold": [
        "warm winter clothing",
        "jacket for cold weather",
        "hoodie and warm outfit"
    ],
    "cool": [
        "light jacket outfit",
        "cool weather clothing",
        "layered outfit for mild weather"
    ],
    "warm": [
        "light clothing for warm weather",
        "casual spring outfit",
        "comfortable breathable outfit"
    ],
    "hot": [
        "summer outfit",
        "very light clothing for hot weather",
        "t shirt and shorts outfit"
    ]
}

# ─────────────────────────────────────────────
# Weather Prompts
# ─────────────────────────────────────────────

WEATHER_PROMPTS = {
    "rainy": [
        "rain jacket waterproof clothing",
        "rainy day outfit",
        "water resistant clothing"
    ],
    "snowy": [
        "snow outfit winter gear",
        "snow jacket and boots",
        "outfit for snowy weather"
    ],
    "windy": [
        "windbreaker jacket outfit",
        "clothing for windy weather",
        "light protective jacket"
    ],
    "humid": [
        "breathable clothing humid weather",
        "light cotton clothing",
        "summer humid outfit"
    ],
    "dry": [
        "dry weather casual outfit",
        "regular everyday clothing",
        "comfortable outfit no rain"
    ]
}

# ─────────────────────────────────────────────
# Core CLIP similarity
# ─────────────────────────────────────────────

def compute_similarity(image_tensor, text_tokens):
    with torch.no_grad():
        image_features = model.encode_image(image_tensor)
        text_features = model.encode_text(text_tokens)

        image_features /= image_features.norm(dim=-1, keepdim=True)
        text_features /= text_features.norm(dim=-1, keepdim=True)

        similarity = (image_features @ text_features.T).softmax(dim=-1)

    return similarity.cpu().numpy()[0]


# ─────────────────────────────────────────────
# Main classifier
# ─────────────────────────────────────────────

def classify_clothing_weather(image_path):
    """
    Returns:
    {
        "temperature": {...},
        "weather": {...}
    }
    """
    image = preprocess(Image.open(image_path)).unsqueeze(0).to(device)

    # ───── Temperature scoring ─────
    temp_scores = {}
    for label, prompts in TEMPERATURE_PROMPTS.items():
        text_tokens = clip.tokenize(prompts).to(device)
        similarity = compute_similarity(image, text_tokens)
        temp_scores[label] = float(np.mean(similarity))

    # Get the key with the highest score
    best_temp = max(temp_scores, key=temp_scores.get)

    # ───── Weather scoring ─────
    weather_scores = {}
    for label, prompts in WEATHER_PROMPTS.items():
        text_tokens = clip.tokenize(prompts).to(device)
        similarity = compute_similarity(image, text_tokens)
        weather_scores[label] = float(np.mean(similarity))

    # Get the key with the highest score
    best_weather = max(weather_scores, key=weather_scores.get)

    return {
        "temperature": best_temp,
        "weather": best_weather
    }


# ─────────────────────────────────────────────
# Normalize scores
# ─────────────────────────────────────────────

def normalize_scores(score_dict):
    total = sum(score_dict.values())
    if total == 0:
        return score_dict

    return {k: v / total for k, v in score_dict.items()}


# ─────────────────────────────────────────────
# Django helper (IMPORTANT)
# ─────────────────────────────────────────────

def process_clothing_item(item):
    try:
        # Now returns strings like {"temperature": "freezing", "weather": "snowy"}
        result = classify_clothing_weather(item.image.path)
        
        # Save these directly to CharFields in your model
        item.detected_temp = result.get("temperature")
        item.detected_weather = result.get("weather")
        item.save()

    except Exception as e:
        print(f"Classification failed for item {item.id}: {e}")


# ─────────────────────────────────────────────
# Bulk processing (for existing items)
# ─────────────────────────────────────────────

def process_all_items(queryset):
    """
    queryset = ClothingItem.objects.all()
    """

    for item in queryset:
        if not item.detected_temp or not item.detected_weather:
            process_clothing_item(item)
