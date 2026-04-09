import os
import io
from pathlib import Path
from urllib.parse import urlparse, unquote
from typing import Dict, List, Optional, Tuple
from uuid import uuid4

from django.conf import settings
from django.core.files import File
from django.core.files.base import ContentFile
from django.core.files.storage import default_storage
from PIL import Image

from drf_spectacular.utils import extend_schema
from rest_framework import serializers, viewsets
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from ai_models.classification.attribute_clip import extract_attributes
from ai_models.classification.clothing_classification import (
    classify_subcategory,
    map_category_from_subcategory,
)
from ai_models.classification.occasion import predict_occasion_details
from ai_models.classification.shoe_metadata import classify_shoe_metadata
from ai_models.classification.weather import classify_clothing_weather

from ..models import ClothingItem, StorageUnit
from ..metadata_normalization import (
    normalize_attributes,
    normalize_color_label,
    normalize_subcategory_label,
)
from ..serializer import ClothingItemSerializer, ClothingItemUpdateSerializer

from ai_models.segmentation.segmentation_utill import segment_image
from ai_models.utils.auth_util import is_clothing, is_shoe as is_shoe_item
from ai_models.utils.color_extraction_util import extract_colors_with_names

UNKNOWN_COLORS = {"dominant_color": "Unknown", "secondary_color": "Unknown"}
DEFAULT_OCCASION = "Casual"
DEFAULT_OCCASION_CONFIDENCE = 0.0
MIN_TEMPERATURE_CONFIDENCE = 0.31
MIN_TEMPERATURE_MARGIN = 0.004
MIN_WEATHER_CONFIDENCE = 0.30
MIN_WEATHER_MARGIN = 0.005
MIN_PRECIPITATION_CONFIDENCE = 0.50
MIN_PRECIPITATION_MARGIN = 0.030
SHOE_LOCKED_CATEGORY = "Shoes"
SHOE_SLOT_KEYS = [
    "shoe",
    "shoes",
    "sneaker",
    "boot",
    "heel",
    "footwear",
    "slipper",
    "sandal",
    "loafer",
    "flip flop",
]


class ClothingProcessRequestSerializer(serializers.Serializer):
    image = serializers.ImageField(required=True)
    is_shoe = serializers.BooleanField(required=False, default=False)


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


def _first_value(raw):
    if isinstance(raw, list):
        return raw[0] if raw else None
    return raw


def _normalize_update_payload(payload: Dict) -> Dict:
    normalized: Dict = {}
    for key, value in payload.items():
        if key == "attributes":
            normalized[key] = _coerce_attributes(value)
        else:
            normalized[key] = _first_value(value)
    return normalized


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


def _resolve_media_path_safe(source_url: str) -> Optional[Path]:
    raw = str(source_url or "").strip()
    if not raw:
        return None

    parsed = urlparse(raw)
    media_url = str(getattr(settings, "MEDIA_URL", "/media/") or "/media/")
    media_parsed = urlparse(media_url)
    media_path = unquote(media_parsed.path or "/media/")
    if not media_path.startswith("/"):
        media_path = f"/{media_path}"
    if not media_path.endswith("/"):
        media_path = f"{media_path}/"

    source_path = unquote(parsed.path or raw)
    if not source_path:
        return None

    if (parsed.scheme or parsed.netloc) and media_parsed.netloc:
        if parsed.netloc.lower() != media_parsed.netloc.lower():
            return None

    if (parsed.scheme or parsed.netloc) and media_parsed.scheme and parsed.scheme:
        if parsed.scheme.lower() != media_parsed.scheme.lower():
            return None

    if not source_path.startswith("/"):
        source_path = f"/{source_path.lstrip('/')}"
    if not source_path.startswith(media_path):
        return None

    relative = source_path[len(media_path) :].replace("\\", "/").lstrip("/")
    if not relative:
        return None

    media_root = Path(settings.MEDIA_ROOT).resolve()
    candidate = (media_root / relative).resolve()
    try:
        candidate.relative_to(media_root)
    except ValueError:
        return None
    return candidate


def _persist_original_upload(image_file, request) -> Tuple[str, Path]:
    original_name = getattr(image_file, "name", "") or ""
    extension = Path(original_name).suffix.lower()
    if extension not in {".jpg", ".jpeg", ".png", ".webp"}:
        extension = ".jpg"

    relative_path = f"clothing/review/{uuid4().hex}{extension}"
    try:
        image_file.seek(0)
    except Exception:
        pass
    saved_path = default_storage.save(relative_path, image_file)
    try:
        image_file.seek(0)
    except Exception:
        pass

    normalized_relative = saved_path.replace("\\", "/")
    original_url = request.build_absolute_uri(f"{settings.MEDIA_URL}{normalized_relative}")
    original_path = Path(settings.MEDIA_ROOT) / normalized_relative
    return original_url, original_path


def _extract_colors_safe(image_path: Path) -> Dict[str, str]:
    try:
        return extract_colors_with_names(str(image_path))
    except Exception:
        return UNKNOWN_COLORS.copy()


def _predict_occasion_safe(image_path: Path) -> Tuple[Optional[str], float]:
    try:
        details = predict_occasion_details(image_path)
        occasion = _coerce_optional_label(details.get("occasion"))
        confidence = float(details.get("confidence") or 0.0)
        return occasion, confidence
    except Exception:
        return None, DEFAULT_OCCASION_CONFIDENCE


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
    return normalize_attributes(raw_attributes)


def _coerce_optional_label(raw_label):
    candidate = _first_value(raw_label)
    text = str(candidate or "").strip()
    return text or None


def _is_shoe_metadata(category: Optional[str], subcategory: Optional[str]) -> bool:
    blob = f"{category or ''} {subcategory or ''}".lower()
    return any(key in blob for key in SHOE_SLOT_KEYS)


def _classify_weather_safe(
    image_path: Path,
    category: Optional[str] = None,
    subcategory: Optional[str] = None,
) -> Tuple[Optional[str], Optional[str]]:
    try:
        result = classify_clothing_weather(
            str(image_path),
            category=category,
            subcategory=subcategory,
        )
        detected_temp = _coerce_optional_label(result.get("temperature"))
        detected_weather = _coerce_optional_label(result.get("weather"))

        temp_conf = float(result.get("temperature_confidence") or 0.0)
        temp_margin = float(result.get("temperature_margin") or 0.0)
        weather_conf = float(result.get("weather_confidence") or 0.0)
        weather_margin = float(result.get("weather_margin") or 0.0)
        is_precipitation_specific = bool(result.get("is_precipitation_specific"))

        if detected_temp and (
            temp_conf < MIN_TEMPERATURE_CONFIDENCE
            or temp_margin < MIN_TEMPERATURE_MARGIN
        ):
            detected_temp = None

        if detected_weather:
            if detected_weather in {"rainy", "snowy"} and not is_precipitation_specific:
                if (
                    weather_conf < MIN_PRECIPITATION_CONFIDENCE
                    or weather_margin < MIN_PRECIPITATION_MARGIN
                ):
                    detected_weather = None
            elif (
                weather_conf < MIN_WEATHER_CONFIDENCE
                or weather_margin < MIN_WEATHER_MARGIN
            ):
                detected_weather = None

        return detected_temp, detected_weather
    except Exception:
        return None, None


def clothing_process(request):

    image = request.FILES.get("image")

    if not image:
        return Response({"error": "Image required"}, status=400)

    is_shoe = _as_bool(request.data.get("is_shoe", False))

    # -------- CLIP --------
    auth_error = _authenticate_item(image.file, is_shoe)
    if auth_error:
        return Response(auth_error, status=400)


    try:
        original_url, original_path = _persist_original_upload(image, request)
    except Exception:
        return Response({"error": "Failed to persist upload"}, status=500)

    # -------- SEGMENT --------
    segmented_url = None
    segmentation_failed = False
    segmentation_message = ""
    try:
        try:
            image.seek(0)
        except Exception:
            pass
        segmented_path = segment_image(image)
        segmented_url = request.build_absolute_uri(segmented_path)
    except Exception:
        segmentation_failed = True
        segmentation_message = "Segmentation failed. You can continue without segmentation."

    if segmented_url:
        resolved_segmented = _resolve_media_path_safe(segmented_url)
        if not resolved_segmented or not resolved_segmented.exists():
            segmentation_failed = True
            segmentation_message = "Segmented file missing. You can continue without segmentation."
            segmented_url = None
            image_path = original_path
        else:
            image_path = resolved_segmented
    else:
        image_path = original_path

    if not image_path.exists():
        return Response({"error": "Image missing"}, status=500)

    # -------- COLORS --------
    colors = _extract_colors_safe(image_path)
    
    # -------- CLASSIFICATION + ATTRIBUTES --------
    occasion = None
    occasion_conf = DEFAULT_OCCASION_CONFIDENCE
    if is_shoe:
        category, subcategory, occasion, attributes = classify_shoe_metadata(image_path)
        category = SHOE_LOCKED_CATEGORY
    else:
        occasion, occasion_conf = _predict_occasion_safe(image_path)
        category, subcategory, attributes = _classify_clothing_safe(image_path)

    # -------- WEATHER LABELS --------
    detected_temp, detected_weather = _classify_weather_safe(
        image_path,
        category=category,
        subcategory=subcategory,
    )
    attributes = normalize_attributes(attributes)
    occasion = _coerce_optional_label(occasion)
    if is_shoe:
        occasion = occasion or DEFAULT_OCCASION
    detected_temp = _coerce_optional_label(detected_temp)
    detected_weather = _coerce_optional_label(detected_weather)

    result = {
        "original_image": original_url,
        "segmented_image": segmented_url,
        "segmentation_failed": segmentation_failed,
        "dominant_color": normalize_color_label(
            colors.get("dominant_color", UNKNOWN_COLORS["dominant_color"])
        ) or UNKNOWN_COLORS["dominant_color"],
        "secondary_color": normalize_color_label(
            colors.get("secondary_color", UNKNOWN_COLORS["secondary_color"])
        ) or UNKNOWN_COLORS["secondary_color"],
        "category": category,
        "subcategory": subcategory,
        "occasion": occasion,
        "occasion_confidence": occasion_conf,
        "attributes": attributes,
        "detected_temp": detected_temp,
        "detected_weather": detected_weather,
        "is_shoe": is_shoe,
    }
    if segmentation_message:
        result["segmentation_message"] = segmentation_message

    return Response(result, status=200)

def clothing_save(request):
    data = request.data

    segmented_url = data.get("segmented_image")
    original_url = data.get("original_image")
    use_segmentation = _as_bool(data.get("use_segmentation", True))
    is_shoe = _as_bool(data.get("is_shoe", False))
    storage_id = data.get("storage_unit")

    if use_segmentation and not segmented_url and original_url:
        use_segmentation = False

    source_url = segmented_url if use_segmentation else (original_url or segmented_url)
    if not source_url or not storage_id:
        return Response({"error": "image source and storage_unit required"}, status=400)

    image_path = _resolve_media_path_safe(source_url)
    if image_path is None:
        return Response({"error": "Invalid image source"}, status=400)

    if not image_path.exists():
        return Response({"error": "Image missing"}, status=400)

    try:
        storage = StorageUnit.objects.get(id=storage_id, user=request.user)
    except StorageUnit.DoesNotExist:
        return Response({"error": "Invalid storage unit"}, status=400)

    required_fields = ["dominant_color", "subcategory"]
    if not is_shoe:
        required_fields.append("category")
    missing_fields = [f for f in required_fields if not data.get(f)]
    if missing_fields:
        return Response({"error": f"Missing fields: {', '.join(missing_fields)}"}, status=400)

    attributes = _coerce_attributes(data.get("attributes", []))
    detected_temp = _coerce_optional_label(data.get("detected_temp"))
    detected_weather = _coerce_optional_label(data.get("detected_weather"))
    occasion = _coerce_optional_label(data.get("occasion"))
    category = str(_first_value(data.get("category")) or "").strip()
    raw_subcategory = _first_value(data.get("subcategory"))
    subcategory = normalize_subcategory_label(raw_subcategory) or str(raw_subcategory or "").strip()
    if is_shoe or _is_shoe_metadata(category, subcategory):
        category = SHOE_LOCKED_CATEGORY
        occasion = occasion or DEFAULT_OCCASION
    dominant_color = normalize_color_label(data.get("dominant_color")) or UNKNOWN_COLORS["dominant_color"]
    secondary_color = normalize_color_label(data.get("secondary_color"))
    if use_segmentation:
        image_content = _normalize_segmented_image(image_path)
    else:
        image_content = ContentFile(image_path.read_bytes())
        image_content.name = image_path.name

    clothing = ClothingItem.objects.create(
        user=request.user,
        storage_unit=storage,
        image=File(image_content, name=image_content.name),
        dominant_color=dominant_color,
        secondary_color=secondary_color,
        category=category,
        subcategory=subcategory,
        occasion=occasion,
        attributes=attributes,
        detected_temp=detected_temp,
        detected_weather=detected_weather,
    )
    if not detected_temp and not detected_weather:
        detected_temp, detected_weather = _classify_weather_safe(
            Path(clothing.image.path),
            category=clothing.category,
            subcategory=clothing.subcategory,
        )
        clothing.detected_temp = _coerce_optional_label(detected_temp)
        clothing.detected_weather = _coerce_optional_label(detected_weather)
        clothing.save(update_fields=["detected_temp", "detected_weather"])

    cleanup_urls = [segmented_url, original_url]
    for cleanup_url in cleanup_urls:
        if not cleanup_url:
            continue
        try:
            cleanup_path = _resolve_media_path_safe(cleanup_url)
            if cleanup_path and cleanup_path.exists() and cleanup_path != Path(clothing.image.path):
                os.remove(cleanup_path)
        except Exception as e:
            print("Cleanup failed:", e)
    
    return Response({"id": clothing.id}, status=201)

def delete_segmented_image(request):
    segmented_url = request.data.get('url') or request.data.get('segmented_image')
    
    if not segmented_url:
        return Response({"detail": "URL not provided."}, status=400)

    file_path = _resolve_media_path_safe(segmented_url)
    if file_path is None:
        return Response({"detail": "Invalid media URL/path."}, status=400)

    try:
        if file_path.exists():
            file_path.unlink()
            return Response({"detail": "File deleted successfully."}, status=200)
        else:
            return Response({"detail": "File not found on server."}, status=404)

    except Exception as e:
        return Response({"detail": f"Error: {str(e)}"}, status=500)


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


def all_clothes(request):
    items = ClothingItem.objects.filter(user=request.user).order_by("-created_at")
    serializer = ClothingItemSerializer(items, many=True, context={"request": request})
    return Response(serializer.data, status=200)

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

def delete_clothing(request, pk):

    try:
        item = ClothingItem.objects.get(id=pk, user=request.user)
    except ClothingItem.DoesNotExist:
        return Response({"error": "Not found"}, status=404)

    item.image.delete(save=False)
    item.delete()

    return Response({"detail": "Deleted"}, status=204)

def update_clothing(request, pk):

    try:
        item = ClothingItem.objects.get(id=pk, user=request.user)
    except ClothingItem.DoesNotExist:
        return Response({"error": "Not found"}, status=404)

    payload = dict(request.data)
    storage_id = payload.pop("storage_unit", None)
    is_shoe_flag = _as_bool(_first_value(payload.pop("is_shoe", False)))

    if storage_id is not None:
        try:
            if isinstance(storage_id, list):
                storage_id = storage_id[0]
            storage = StorageUnit.objects.get(id=storage_id, user=request.user)
        except StorageUnit.DoesNotExist:
            return Response({"error": "Invalid storage unit"}, status=400)

        item.storage_unit = storage
        item.save(update_fields=["storage_unit"])

    payload = _normalize_update_payload(payload)

    if (
        is_shoe_flag
        or _is_shoe_metadata(item.category, item.subcategory)
        or _is_shoe_metadata(payload.get("category"), payload.get("subcategory"))
    ):
        payload["category"] = SHOE_LOCKED_CATEGORY

    if not payload:
        serializer = ClothingItemSerializer(item, context={"request": request})
        return Response(serializer.data, status=200)

    serializer = ClothingItemUpdateSerializer(item, data=payload, partial=True)

    if serializer.is_valid():
        serializer.save()
        refreshed = ClothingItemSerializer(item, context={"request": request})
        return Response(refreshed.data, status=200)

    return Response(serializer.errors, status=400)


def clothing_detail(request, pk):
    try:
        item = ClothingItem.objects.get(id=pk, user=request.user)
    except ClothingItem.DoesNotExist:
        return Response({"error": "Not found"}, status=404)

    serializer = ClothingItemSerializer(item, context={"request": request})
    return Response(serializer.data)


class ClothingViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = ClothingItemSerializer

    @extend_schema(
        summary="Process clothing image",
        request={"multipart/form-data": ClothingProcessRequestSerializer},
    )
    def process(self, request):
        return clothing_process(request)

    @extend_schema(summary="Save processed clothing")
    def save(self, request):
        return clothing_save(request)

    @extend_schema(summary="Delete segmented preview image")
    def delete_segmented(self, request):
        return delete_segmented_image(request)

    @extend_schema(summary="List recent clothing")
    def recent(self, request):
        return recent_clothes(request)

    @extend_schema(summary="List all clothing")
    def all(self, request):
        return all_clothes(request)

    @extend_schema(summary="Toggle clothing favourite", request=None)
    def toggle_favourite(self, request, pk=None):
        return toggle_favourite(request, pk)

    @extend_schema(summary="Get clothing detail")
    def retrieve(self, request, pk=None):
        return clothing_detail(request, pk)

    # Backward-compatible alias for older action mappings.
    @extend_schema(exclude=True)
    def retrieve_item(self, request, pk=None):
        return self.retrieve(request, pk)

    @extend_schema(summary="Delete clothing")
    def delete_item(self, request, pk=None):
        return delete_clothing(request, pk)

    @extend_schema(summary="Update clothing")
    def update_item(self, request, pk=None):
        return update_clothing(request, pk)

