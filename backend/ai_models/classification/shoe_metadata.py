from __future__ import annotations

from pathlib import Path
from typing import List, Tuple, Union

from .attribute_clip import extract_shoe_details

DEFAULT_SHOE_CATEGORY = "Shoes"
DEFAULT_SHOE_SUBCATEGORY = "Shoes"
DEFAULT_SHOE_OCCASION = "Casual"


def _title_label(raw: object) -> str:
    text = str(raw or "").replace("_", " ").replace("-", " ").strip()
    if not text:
        return ""
    return " ".join(part.capitalize() for part in text.split())

# Main function to classify shoe metadata from an image.
def classify_shoe_metadata(image_path: Union[str, Path]) -> Tuple[str, str, str, List[str]]:
    """
    Return normalized shoe metadata tuple:
    (category, subcategory, occasion, attributes)
    """
    try:
        details = extract_shoe_details(str(image_path))
        category = DEFAULT_SHOE_CATEGORY
        subcategory = _title_label(details.get("shoe_type", DEFAULT_SHOE_SUBCATEGORY)) or DEFAULT_SHOE_SUBCATEGORY
        occasion = _title_label(details.get("usage", DEFAULT_SHOE_OCCASION)) or DEFAULT_SHOE_OCCASION
        attributes = list(details.get("attributes", []))
        return category, subcategory, occasion, attributes
    except Exception:
        return DEFAULT_SHOE_CATEGORY, DEFAULT_SHOE_SUBCATEGORY, DEFAULT_SHOE_OCCASION, []
