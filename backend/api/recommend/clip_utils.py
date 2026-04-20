import os
import logging
from functools import lru_cache
from typing import Optional

import numpy as np
import torch
from PIL import Image
from transformers import CLIPModel, CLIPProcessor


MODEL_NAME = "patrickjohncyh/fashion-clip"
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

_MODEL: Optional[CLIPModel] = None
_PROCESSOR: Optional[CLIPProcessor] = None
LOGGER = logging.getLogger(__name__)

CLIP_SIM_LOW = 0.15
CLIP_SIM_HIGH = 0.38


def _get_model() -> CLIPModel:
    global _MODEL
    if _MODEL is None:
        _MODEL = CLIPModel.from_pretrained(MODEL_NAME).to(DEVICE)
        _MODEL.eval()
    return _MODEL


def _get_processor() -> CLIPProcessor:
    global _PROCESSOR
    if _PROCESSOR is None:
        _PROCESSOR = CLIPProcessor.from_pretrained(MODEL_NAME, use_fast=True)
    return _PROCESSOR


def _normalize(vec: np.ndarray) -> np.ndarray:
    norm = np.linalg.norm(vec)
    if norm == 0:
        return vec
    return vec / norm


@lru_cache(maxsize=512)
def get_text_embedding(text: str) -> Optional[np.ndarray]:
    cleaned = (text or "").strip()
    if not cleaned:
        return None
    processor = _get_processor()
    model = _get_model()
    inputs = processor(text=[cleaned], return_tensors="pt", padding=True).to(DEVICE)
    with torch.no_grad():
        features = model.get_text_features(**inputs)
    vec = features[0].detach().cpu().numpy().astype(np.float32)
    return _normalize(vec)


@lru_cache(maxsize=2048)
def _cached_image_embedding(image_path: str, mtime: int) -> Optional[np.ndarray]:
    if not image_path:
        return None
    if not os.path.exists(image_path):
        return None
    try:
        image = Image.open(image_path).convert("RGB")
    except Exception:
        return None
    processor = _get_processor()
    model = _get_model()
    inputs = processor(images=image, return_tensors="pt").to(DEVICE)
    with torch.no_grad():
        features = model.get_image_features(**inputs)
    vec = features[0].detach().cpu().numpy().astype(np.float32)
    return _normalize(vec)


def get_image_embedding(image_path: str) -> Optional[np.ndarray]:
    if not image_path:
        return None
    try:
        mtime = int(os.path.getmtime(image_path))
    except Exception:
        mtime = 0
    return _cached_image_embedding(image_path, mtime)


def cosine_similarity(vec_a: Optional[np.ndarray], vec_b: Optional[np.ndarray]) -> float:
    if vec_a is None or vec_b is None:
        return 0.5
    raw = float(np.dot(vec_a, vec_b))
    LOGGER.debug("raw cosine similarity: %.4f", raw)

    if CLIP_SIM_HIGH <= CLIP_SIM_LOW:
        # Defensive fallback to neutral in case calibration constants are invalid.
        return 0.5

    stretched = (raw - CLIP_SIM_LOW) / (CLIP_SIM_HIGH - CLIP_SIM_LOW)
    return max(min(stretched, 1.0), 0.0)
