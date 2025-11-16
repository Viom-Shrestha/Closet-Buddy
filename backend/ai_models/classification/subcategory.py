import time
from PIL import Image
import torch
from transformers import AutoModelForImageClassification, AutoImageProcessor

# Load once
processor = AutoImageProcessor.from_pretrained(
    "prithivMLmods/Fashion-Product-subCategory"
)
model = AutoModelForImageClassification.from_pretrained(
    "prithivMLmods/Fashion-Product-subCategory"
)

def test_subcategory(image_pil):
    """
    Runs classification and returns:
    - predicted label
    - execution time
    """
    start = time.time()

    inputs = processor(images=image_pil, return_tensors="pt")
    with torch.no_grad():
        outputs = model(**inputs)
        pred = outputs.logits.argmax(-1).item()

    label = model.config.id2label[pred]

    end = time.time()

    return label, round(end - start, 4)
