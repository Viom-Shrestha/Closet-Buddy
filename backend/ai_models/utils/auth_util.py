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
    "a photo of a dress",
    "a photo of a hoodie",
]

SHOE_LABELS = [
    "a photo of shoes",
    "a photo of footwear",
    "a photo of sneakers",
    "a photo of boots",
    "a photo of sandals",
]

NON_CLOTHING_LABELS = [
    "a photo of a person",
    "a photo of furniture",
    "a photo of electronics",
    "a photo of food",
    "a photo of an animal",
    "a photo of a random object"
]


def _authenticate(image_path, valid_labels, result_key):
    image = preprocess(Image.open(image_path).convert("RGB")) \
                .unsqueeze(0).to(device)

    with torch.no_grad():
        image_features = model.encode_image(image)
        image_features /= image_features.norm(dim=-1, keepdim=True)

        valid_text = clip.tokenize(valid_labels).to(device)
        non_clothing_text = clip.tokenize(NON_CLOTHING_LABELS).to(device)

        valid_features = model.encode_text(valid_text)
        non_clothing_features = model.encode_text(non_clothing_text)

        valid_features /= valid_features.norm(dim=-1, keepdim=True)
        non_clothing_features /= non_clothing_features.norm(dim=-1, keepdim=True)

        valid_score = (image_features @ valid_features.T).mean()
        non_clothing_score = (image_features @ non_clothing_features.T).mean()

    is_valid = valid_score > non_clothing_score

    return {
        result_key: bool(is_valid),
        "confidence": float(valid_score),
        "non_clothing_score": float(non_clothing_score),
    }


def is_clothing(image_path):
    return _authenticate(
        image_path=image_path,
        valid_labels=CLOTHING_LABELS,
        result_key="is_clothing",
    )


def is_shoe(image_path):
    return _authenticate(
        image_path=image_path,
        valid_labels=SHOE_LABELS,
        result_key="is_shoe",
    )

