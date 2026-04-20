from pathlib import Path
from typing import List, Tuple

import torch
import torch.nn as nn
import torch.nn.functional as F
from PIL import Image
from torchvision import models, transforms

# Class order must match training order for the checkpoint.
CLASS_NAMES: List[str] = [
    "Coat",
    "Dress",
    "Hoodie",
    "Jacket",
    "Jeans",
    "Jumpsuit",
    "Pants",
    "Shirt",
    "Shorts",
    "Skirt",
    "Sweater",
    "TShirt",
]

NUM_CLASSES = len(CLASS_NAMES)
DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")
MODEL_PATH = Path(__file__).with_name("clothing_classification.pth")

_MODEL = None

_TRANSFORM = transforms.Compose(
    [
        transforms.Resize((256, 256)),
        transforms.ToTensor(),
        transforms.Normalize(
            [0.485, 0.456, 0.406],
            [0.229, 0.224, 0.225],
        ),
    ]
)


def _load_checkpoint(path: Path):
    try:
        return torch.load(path, map_location=DEVICE, weights_only=False)
    except TypeError:
        return torch.load(path, map_location=DEVICE)


def _build_model() -> torch.nn.Module:
    model = models.efficientnet_b0(weights=None)
    model.classifier = nn.Sequential(
        nn.Dropout(0.4),
        nn.Linear(model.classifier[1].in_features, NUM_CLASSES),
    )
    state = _load_checkpoint(MODEL_PATH)
    if not isinstance(state, dict):
        raise RuntimeError("Unsupported checkpoint format for clothing classification model")
    model.load_state_dict(state, strict=True)
    model.to(DEVICE)
    model.eval()
    return model


def _model() -> torch.nn.Module:
    global _MODEL
    if _MODEL is None:
        if not MODEL_PATH.exists():
            raise FileNotFoundError(f"Model file not found: {MODEL_PATH}")
        _MODEL = _build_model()
    return _MODEL


def classify_subcategory(image_pil: Image.Image) -> Tuple[str, float]:
    image = _TRANSFORM(image_pil.convert("RGB")).unsqueeze(0).to(DEVICE)
    with torch.no_grad():
        outputs = _model()(image)
        probs = F.softmax(outputs, dim=1)
        confidence, pred = torch.max(probs, 1)
    return CLASS_NAMES[pred.item()], float(confidence.item())


def map_category_from_subcategory(subcategory: str) -> str:
    label = (subcategory or "").strip().lower().replace(" ", "")

    if label in {"coat", "jacket"}:
        return "Outerwear"
    if label in {"jeans", "pants", "shorts", "skirt"}:
        return "Bottomwear"
    # Dress/Jumpsuit are full-body, but we constrain to requested 3 buckets.
    return "Topwear"


def predict(image_path: str) -> Tuple[str, float]:
    with Image.open(image_path).convert("RGB") as image:
        return classify_subcategory(image)


if __name__ == "__main__":
    test_image_path = "test_image.jpg"
    category, confidence = predict(test_image_path)
    print("Prediction:", category)
    print("Confidence:", round(confidence, 3))
