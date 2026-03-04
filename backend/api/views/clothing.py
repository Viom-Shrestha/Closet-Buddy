import os
from pathlib import Path
from urllib.parse import urlparse
from typing import Dict, List, Optional, Tuple

from django.conf import settings
from django.core.files import File
from PIL import Image

from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from ai_models.classification.attribute_clip import extract_attributes, extract_shoe_details
from ai_models.classification.occasion import predict_occasion
from ai_models.classification.subcategory import test_subcategory

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
    value = (subcategory or "").lower()

    if any(k in value for k in ["shoe", "sneaker", "boot", "sandal", "heel", "loafer"]):
        return "Shoe"
    if any(k in value for k in ["shirt", "tee", "top", "blouse", "jacket", "coat", "hoodie", "sweater"]):
        return "Topwear"
    if any(k in value for k in ["pant", "jean", "short", "skirt", "trouser", "legging"]):
        return "Bottomwear"
    if any(k in value for k in ["dress", "jumpsuit"]):
        return "One-piece"
    return "Clothing"


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
    try:
        with Image.open(image_path).convert("RGB") as segmented_image:
            predicted_subcategory, _ = test_subcategory(segmented_image)
        subcategory = _title_label(predicted_subcategory) or "Shirt"
        category = _infer_category(subcategory)
    except Exception:
        category = "Topwear"
        subcategory = "Shirt"

    try:
        attributes = extract_attributes(image_path, subcategory)
    except Exception:
        attributes = []

    return category, subcategory, attributes


def _coerce_attributes(raw_attributes) -> List:
    if isinstance(raw_attributes, list):
        return raw_attributes
    return []


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

    result = {
        "segmented_image": segmented_url,
        "dominant_color": colors.get("dominant_color", UNKNOWN_COLORS["dominant_color"]),
        "secondary_color": colors.get("secondary_color", UNKNOWN_COLORS["secondary_color"]),
        "category": category,
        "subcategory": subcategory,
        "occasion": occasion,
        "occasion_confidence": occasion_conf,
        "attributes": attributes,
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

    with open(image_path, "rb") as f:
        attributes = _coerce_attributes(data.get("attributes", []))

        clothing = ClothingItem.objects.create(
            user=request.user,
            storage_unit=storage,
            image=File(f, name=image_path.name),
            dominant_color=data["dominant_color"],
            secondary_color=data.get("secondary_color"),
            category=data["category"],
            subcategory=data["subcategory"],
            occasion=data.get("occasion"),
            attributes=attributes,
        )
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

