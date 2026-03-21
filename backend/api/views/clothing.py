import os
import io
from pathlib import Path
from urllib.parse import urlparse
from typing import Dict, List, Optional, Tuple

from django.conf import settings
from django.core.files import File
from django.core.files.base import ContentFile
from PIL import Image

from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from ai_models.classification.attribute_clip import extract_attributes, extract_shoe_details
from ai_models.classification.clothing_classification import (
    classify_subcategory,
    map_category_from_subcategory,
)
from ai_models.classification.occasion import predict_occasion
from ai_models.classification.weather import classify_clothing_weather

from ..models import ClothingItem, StorageUnit
from ..serializer import ClothingItemSerializer, ClothingItemUpdateSerializer

from ai_models.segmentation.segmentation_utill import segment_image
from ai_models.utils.auth_util import is_clothing, is_shoe as is_shoe_item
from ai_models.utils.color_extraction_util import extract_colors_with_names

UNKNOWN_COLORS = {"dominant_color": "Unknown", "secondary_color": "Unknown"}
DEFAULT_OCCASION = "Casual"
DEFAULT_OCCASION_CONFIDENCE = 0.0


def _as_bool(value):
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.lower() in ["true", "1", "yes", "on"]
    return bool(value)


def _title_label(raw):
    if not raw:
        return ""
    cleaned = str(raw).replace("_", " ").replace("-", " ").strip()
    return " ".join(part.capitalize() for part in cleaned.split())


def _infer_category(subcategory):
    return map_category_from_subcategory(subcategory)


def _is_shoe_label(category: str, subcategory: str) -> bool:
    text = f"{category} {subcategory}".lower()
    keys = ["shoe", "sneaker", "boot", "heel", "footwear", "slipper", "sandal", "loafer"]
    return any(key in text for key in keys)


def _is_bottom_label(category: str, subcategory: str) -> bool:
    text = f"{category} {subcategory}".lower()
    keys = ["pant", "trouser", "jean", "short", "skirt", "bottom", "jogger", "legging", "cargo"]
    return any(key in text for key in keys)


def _first_value(raw):
    if isinstance(raw, list):
        return raw[0] if raw else None
    return raw


def _coerce_float(raw, fallback: float, min_value: float, max_value: float) -> float:
    candidate = _first_value(raw)
    try:
        parsed = float(candidate)
    except (TypeError, ValueError):
        parsed = fallback
    return max(min(parsed, max_value), min_value)


def _default_fit_values(category: str, subcategory: str) -> Dict[str, float]:
    if _is_shoe_label(category, subcategory):
        return {"fit_scale": 1.08, "fit_offset_x": 0.0, "fit_offset_y": -0.03}
    if _is_bottom_label(category, subcategory):
        return {"fit_scale": 1.12, "fit_offset_x": 0.0, "fit_offset_y": -0.05}
    return {"fit_scale": 1.0, "fit_offset_x": 0.0, "fit_offset_y": 0.0}


def _extract_fit_values(data, category: str, subcategory: str) -> Dict[str, float]:
    defaults = _default_fit_values(category, subcategory)
    return {
        "fit_scale": _coerce_float(data.get("fit_scale"), defaults["fit_scale"], 0.5, 2.0),
        "fit_offset_x": _coerce_float(data.get("fit_offset_x"), defaults["fit_offset_x"], -1.0, 1.0),
        "fit_offset_y": _coerce_float(data.get("fit_offset_y"), defaults["fit_offset_y"], -1.0, 1.0),
    }


def _normalize_segmented_image(image_path: Path) -> ContentFile:
    # Normalize cutouts to a consistent canvas so overlay sizing is predictable.
    with Image.open(image_path).convert("RGBA") as raw_image:
        alpha = raw_image.getchannel("A")
        opaque_bbox = alpha.point(lambda a: 255 if a > 8 else 0).getbbox()
        cropped = raw_image.crop(opaque_bbox) if opaque_bbox else raw_image.copy()

        target_width = 1024
        target_height = 1024
        padding_ratio = 0.08
        inner_width = int(target_width * (1 - (2 * padding_ratio)))
        inner_height = int(target_height * (1 - (2 * padding_ratio)))

        scale = min(inner_width / max(cropped.width, 1), inner_height / max(cropped.height, 1))
        resized_width = max(1, int(cropped.width * scale))
        resized_height = max(1, int(cropped.height * scale))

        resampling = getattr(Image, "Resampling", Image).LANCZOS
        resized = cropped.resize((resized_width, resized_height), resampling)
        canvas = Image.new("RGBA", (target_width, target_height), (0, 0, 0, 0))
        paste_x = (target_width - resized_width) // 2
        paste_y = (target_height - resized_height) // 2
        canvas.paste(resized, (paste_x, paste_y), resized)

        buffer = io.BytesIO()
        canvas.save(buffer, format="PNG", optimize=True)

    output = ContentFile(buffer.getvalue())
    output.name = f"{image_path.stem}_norm.png"
    return output


def _auth_error_payload(is_shoe: bool) -> str:
    return "Not a shoe item" if is_shoe else "Not a clothing item"


def _authenticate_item(image_file, is_shoe: bool) -> Optional[Dict]:
    auth_result = is_shoe_item(image_file) if is_shoe else is_clothing(image_file)
    passed = auth_result.get("is_shoe") if is_shoe else auth_result.get("is_clothing")

    if passed:
        return None

    return {
        "error": _auth_error_payload(is_shoe),
        "confidence": auth_result.get("confidence", 0.0),
    }


def _resolve_segmented_path(segmented_url: str) -> Path:
    parsed = urlparse(segmented_url)
    relative = parsed.path.replace(settings.MEDIA_URL, "")
    return Path(settings.MEDIA_ROOT) / relative


def _extract_colors_safe(image_path: Path) -> Dict[str, str]:
    try:
        return extract_colors_with_names(str(image_path))
    except Exception:
        return UNKNOWN_COLORS.copy()


def _predict_occasion_safe(image_path: Path) -> Tuple[str, float]:
    try:
        return predict_occasion(image_path)
    except Exception:
        return DEFAULT_OCCASION, DEFAULT_OCCASION_CONFIDENCE


def _classify_shoe_safe(image_path: Path) -> Tuple[str, str, str, List[str]]:
    try:
        shoe_details = extract_shoe_details(image_path)
        category = "Shoe"
        subcategory = _title_label(shoe_details.get("shoe_type", "Shoes"))
        occasion = _title_label(shoe_details.get("usage", DEFAULT_OCCASION))
        attributes = list(shoe_details.get("attributes", []))
        return category, subcategory, occasion, attributes
    except Exception:
        return "Shoe", "Shoes", DEFAULT_OCCASION, []


def _classify_clothing_safe(image_path: Path) -> Tuple[str, str, List[str]]:
    subcategory = "Shirt"
    category = "Topwear"
    try:
        with Image.open(image_path).convert("RGB") as segmented_image:
            predicted_subcategory, _ = classify_subcategory(segmented_image)
        subcategory = _title_label(predicted_subcategory) or "Shirt"
        category = _infer_category(subcategory)
    except Exception:
        # Backward-compatible fallback to prior classifier when local .pth inference fails.
        try:
            from ai_models.classification.subcategory import test_subcategory

            with Image.open(image_path).convert("RGB") as segmented_image:
                predicted_subcategory, _ = test_subcategory(segmented_image)
            subcategory = _title_label(predicted_subcategory) or "Shirt"
            category = _infer_category(subcategory)
        except Exception:
            pass

    try:
        attributes = extract_attributes(image_path, subcategory)
    except Exception:
        attributes = []

    return category, subcategory, attributes


def _coerce_attributes(raw_attributes) -> List:
    if isinstance(raw_attributes, list):
        return raw_attributes
    return []


def _coerce_weather_label(raw_label):
    candidate = _first_value(raw_label)
    if candidate is None:
        return None
    text = str(candidate).strip()
    return text or None


def _classify_weather_safe(image_path: Path) -> Tuple[Optional[str], Optional[str]]:
    try:
        result = classify_clothing_weather(str(image_path))
        return result.get("temperature"), result.get("weather")
    except Exception:
        return None, None


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def clothing_process(request):

    image = request.FILES.get("image")

    if not image:
        return Response({"error": "Image required"}, status=400)

    is_shoe = _as_bool(request.data.get("is_shoe", False))

    # -------- CLIP --------
    auth_error = _authenticate_item(image.file, is_shoe)
    if auth_error:
        return Response(auth_error, status=400)


    # -------- SEGMENT --------
    try:
        segmented_path = segment_image(image)
        segmented_url = request.build_absolute_uri(segmented_path)

    except Exception:
        return Response({"error": "Segmentation failed"}, status=500)

    image_path = _resolve_segmented_path(segmented_url)
    
    if not image_path.exists():
        return Response({"error": "Segmented file missing"}, status=500)

    # -------- COLORS --------
    colors = _extract_colors_safe(image_path)
    
    # -------- Occasion --------
    occasion, occasion_conf = _predict_occasion_safe(image_path)

    # -------- CLASSIFICATION + ATTRIBUTES --------
    if is_shoe:
        category, subcategory, occasion, attributes = _classify_shoe_safe(image_path)
    else:
        category, subcategory, attributes = _classify_clothing_safe(image_path)

    # -------- WEATHER LABELS --------
    detected_temp, detected_weather = _classify_weather_safe(image_path)

    result = {
        "segmented_image": segmented_url,
        "dominant_color": colors.get("dominant_color", UNKNOWN_COLORS["dominant_color"]),
        "secondary_color": colors.get("secondary_color", UNKNOWN_COLORS["secondary_color"]),
        "category": category,
        "subcategory": subcategory,
        "occasion": occasion,
        "occasion_confidence": occasion_conf,
        "attributes": attributes,
        "detected_temp": detected_temp,
        "detected_weather": detected_weather,
        "is_shoe": is_shoe,
    }

    return Response(result, status=200)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def clothing_save(request):
    data = request.data

    segmented_url = data.get("segmented_image")
    storage_id = data.get("storage_unit")

    if not segmented_url or not storage_id:
        return Response({"error": "segmented_image and storage_unit required"}, status=400)

    image_path = _resolve_segmented_path(segmented_url)

    if not image_path.exists():
        return Response({"error": "Image missing"}, status=400)

    try:
        storage = StorageUnit.objects.get(id=storage_id, user=request.user)
    except StorageUnit.DoesNotExist:
        return Response({"error": "Invalid storage unit"}, status=400)

    missing_fields = [f for f in ["dominant_color", "category", "subcategory"] if not data.get(f)]
    if missing_fields:
        return Response({"error": f"Missing fields: {', '.join(missing_fields)}"}, status=400)

    attributes = _coerce_attributes(data.get("attributes", []))
    fit_values = _extract_fit_values(data, data["category"], data["subcategory"])
    detected_temp = _coerce_weather_label(data.get("detected_temp"))
    detected_weather = _coerce_weather_label(data.get("detected_weather"))

    normalized_image = _normalize_segmented_image(image_path)

    clothing = ClothingItem.objects.create(
        user=request.user,
        storage_unit=storage,
        image=File(normalized_image, name=normalized_image.name),
        dominant_color=data["dominant_color"],
        secondary_color=data.get("secondary_color"),
        category=data["category"],
        subcategory=data["subcategory"],
        occasion=data.get("occasion"),
        attributes=attributes,
        detected_temp=detected_temp,
        detected_weather=detected_weather,
        fit_scale=fit_values["fit_scale"],
        fit_offset_x=fit_values["fit_offset_x"],
        fit_offset_y=fit_values["fit_offset_y"],
    )
    if not detected_temp or not detected_weather:
        detected_temp, detected_weather = _classify_weather_safe(Path(clothing.image.path))
        clothing.detected_temp = detected_temp
        clothing.detected_weather = detected_weather
        clothing.save(update_fields=["detected_temp", "detected_weather"])
    try:
        os.remove(image_path)
    except Exception as e:
        print("Cleanup failed:", e)
    
    return Response({"id": clothing.id}, status=201)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def delete_segmented_image(request):
    segmented_url = request.data.get('url') or request.data.get('segmented_image')
    
    if not segmented_url:
        return Response({"detail": "URL not provided."}, status=400)

    try:
        parsed = urlparse(segmented_url)
        relative_path = parsed.path.replace(settings.MEDIA_URL, "")
        file_path = Path(settings.MEDIA_ROOT) / relative_path

        print(f"DEBUG: Attempting to delete file at: {file_path}")

        if file_path.exists():
            file_path.unlink()
            return Response({"detail": "File deleted successfully."}, status=200)
        else:
            return Response({"detail": "File not found on server."}, status=404)

    except Exception as e:
        print(f"DEBUG: Deletion Error: {str(e)}")
        return Response({"detail": f"Error: {str(e)}"}, status=500)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def recent_clothes(request):
    items = ClothingItem.objects.filter(user=request.user)\
                                .order_by("-created_at")[:6]

    return Response([
        {
            "id": i.id,
            "image": request.build_absolute_uri(i.image.url),
            "is_favourite": i.is_favourite
        }
        for i in items
    ])


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def all_clothes(request):
    items = ClothingItem.objects.filter(user=request.user).order_by("-created_at")
    serializer = ClothingItemSerializer(items, many=True, context={"request": request})
    return Response(serializer.data, status=200)

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def toggle_favourite(request, pk):
    try:
        item = ClothingItem.objects.get(id=pk, user=request.user)
    except ClothingItem.DoesNotExist:
        return Response({"error": "Not found"}, status=404)

    item.is_favourite = not item.is_favourite
    item.save()

    return Response({
        "id": item.id,
        "is_favourite": item.is_favourite
    }, status=200)

@api_view(["DELETE"])
@permission_classes([IsAuthenticated])
def delete_clothing(request, pk):

    try:
        item = ClothingItem.objects.get(id=pk, user=request.user)
    except ClothingItem.DoesNotExist:
        return Response({"error": "Not found"}, status=404)

    item.image.delete(save=False)
    item.delete()

    return Response({"detail": "Deleted"}, status=204)

@api_view(["PUT"])
@permission_classes([IsAuthenticated])
def update_clothing(request, pk):

    try:
        item = ClothingItem.objects.get(id=pk, user=request.user)
    except ClothingItem.DoesNotExist:
        return Response({"error": "Not found"}, status=404)

    payload = dict(request.data)
    storage_id = payload.pop("storage_unit", None)

    if storage_id is not None:
        try:
            if isinstance(storage_id, list):
                storage_id = storage_id[0]
            storage = StorageUnit.objects.get(id=storage_id, user=request.user)
        except StorageUnit.DoesNotExist:
            return Response({"error": "Invalid storage unit"}, status=400)

        item.storage_unit = storage
        item.save(update_fields=["storage_unit"])

    if not payload:
        serializer = ClothingItemSerializer(item, context={"request": request})
        return Response(serializer.data, status=200)

    serializer = ClothingItemUpdateSerializer(item, data=payload, partial=True)

    if serializer.is_valid():
        serializer.save()
        refreshed = ClothingItemSerializer(item, context={"request": request})
        return Response(refreshed.data, status=200)

    return Response(serializer.errors, status=400)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def clothing_detail(request, pk):
    try:
        item = ClothingItem.objects.get(id=pk, user=request.user)
    except ClothingItem.DoesNotExist:
        return Response({"error": "Not found"}, status=404)

    serializer = ClothingItemSerializer(item, context={"request": request})
    return Response(serializer.data)

