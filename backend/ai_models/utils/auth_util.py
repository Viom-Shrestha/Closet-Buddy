import torch
import clip
from PIL import Image

device = "cpu"

model, preprocess = clip.load("ViT-B/32", device=device)

CLOTHING_LABELS = [
    "a photo of clothing",
    "a photo of a shirt",
    "a photo of pants",
    "a photo of a jacket",
    "a photo of shoes",
    "a photo of footwear"
]

NON_CLOTHING_LABELS = [
    "a photo of a person",
    "a photo of furniture",
    "a photo of electronics",
    "a photo of food",
    "a photo of an animal",
    "a photo of a random object"
]

def is_clothing(image_path):
    image = preprocess(Image.open(image_path).convert("RGB")) \
                .unsqueeze(0).to(device)

    with torch.no_grad():
        image_features = model.encode_image(image)
        image_features /= image_features.norm(dim=-1, keepdim=True)

        clothing_text = clip.tokenize(CLOTHING_LABELS).to(device)
        non_clothing_text = clip.tokenize(NON_CLOTHING_LABELS).to(device)

        clothing_features = model.encode_text(clothing_text)
        non_clothing_features = model.encode_text(non_clothing_text)

        clothing_features /= clothing_features.norm(dim=-1, keepdim=True)
        non_clothing_features /= non_clothing_features.norm(dim=-1, keepdim=True)

        clothing_score = (image_features @ clothing_features.T).mean()
        non_clothing_score = (image_features @ non_clothing_features.T).mean()

    return {
    "is_clothing": clothing_score > non_clothing_score,
    "confidence": float(clothing_score)
    }
