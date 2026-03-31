from transformers import CLIPProcessor, CLIPModel
from PIL import Image
import torch
from typing import Dict, List

device =  "cpu"

MODEL_NAME = "patrickjohncyh/fashion-clip"

clip_model = CLIPModel.from_pretrained(MODEL_NAME).to(device)
clip_processor = CLIPProcessor.from_pretrained(MODEL_NAME, use_fast=True)

OCCASION_PROMPTS: Dict[str, List[str]] = {
    "Casual": [
        "casual everyday outfit",
        "smart casual outfit",
        "street casual clothing",
    ],
    "Formal": [
        "formal office wear",
        "business meeting outfit",
        "semi-formal outfit",
    ],
    "Office": [
        "office workwear outfit",
        "business casual office look",
        "professional corporate attire",
    ],
    "Party": [
        "party night outfit",
        "club party clothing",
        "date night outfit",
    ],
    "Date": [
        "date night outfit",
        "romantic dinner outfit",
        "stylish date outfit",
    ],
    "Traditional": [
        "traditional ethnic clothing",
        "cultural festival outfit",
    ],
    "Sport": [
        "sports gym activewear",
        "athletic workout outfit",
        "running training outfit",
    ],
    "Home": [
        "home loungewear pajamas",
        "sleepwear night clothing",
        "comfortable indoor wear",
    ],
    "Travel": [
        "travel airport outfit",
        "long flight comfortable outfit",
    ],
    "Beach": [
        "beach vacation outfit",
        "resort beachwear",
    ],
    "Street": [
        "street style outfit",
        "urban streetwear look",
        "trendy street fashion",
    ],
}

# Flatten prompts for CLIP text tower input.
ALL_PROMPTS: List[str] = []
PROMPT_TO_CATEGORY: List[str] = []
for category, prompts in OCCASION_PROMPTS.items():
    for p in prompts:
        ALL_PROMPTS.append(p)
        PROMPT_TO_CATEGORY.append(category)


def predict_occasion(image_path):

    image = Image.open(image_path).convert("RGB")

    inputs = clip_processor(
        images=image,
        text=ALL_PROMPTS,
        return_tensors="pt",
        padding=True
    ).to(device)

    with torch.no_grad():
        outputs = clip_model(**inputs)

    prompt_probs = outputs.logits_per_image.softmax(dim=1)[0]

    # Aggregate prompt probabilities into category probabilities.
    category_scores: Dict[str, float] = {k: 0.0 for k in OCCASION_PROMPTS.keys()}
    for i, prob in enumerate(prompt_probs):
        category_scores[PROMPT_TO_CATEGORY[i]] += float(prob)

    best_category = max(category_scores, key=category_scores.get)
    confidence = category_scores[best_category]

    sorted_scores = sorted(category_scores.values(), reverse=True)
    second_best = sorted_scores[1] if len(sorted_scores) > 1 else 0.0
    margin = confidence - second_best

    # Safety fallback for low-confidence or ambiguous predictions.
    if confidence < 0.35 or margin < 0.08:
        best_category = "Casual"

    return best_category, round(confidence, 3)
