import io
import os
from pathlib import Path
from urllib.parse import urlparse

from django.conf import settings
from django.core.files import File
from django.core.files.base import ContentFile
from PIL import Image

from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from ai_models.segmentation.segmentation_utill import segment_image
from ai_models.utils.color_extraction_util import extract_colors_with_names

from ..models import AccessoryItem, StorageUnit
from ..serializer import AccessoryItemSerializer

UNKNOWN_COLORS = {"dominant_color": "Unknown", "secondary_color": "Unknown"}


def _resolve_segmented_path(segmented_url: str) -> Path:
    parsed = urlparse(segmented_url)
    relative = parsed.path.replace(settings.MEDIA_URL, "")
    return Path(settings.MEDIA_ROOT) / relative


def _extract_colors_safe(image_path: Path):
    try:
        return extract_colors_with_names(str(image_path))
    except Exception:
        return UNKNOWN_COLORS.copy()


def _normalize_segmented_image(image_path: Path) -> ContentFile:
    with Image.open(image_path).convert("RGBA") as raw_image:
        alpha = raw_image.getchannel("A")
        opaque_bbox = alpha.point(lambda a: 255 if a > 8 else 0).getbbox()
        cropped = raw_image.crop(opaque_bbox) if opaque_bbox else raw_image.copy()

        target_size = 1024
        padding_ratio = 0.08
        inner_size = int(target_size * (1 - (2 * padding_ratio)))
        scale = min(inner_size / max(cropped.width, 1), inner_size / max(cropped.height, 1))
        resized_width = max(1, int(cropped.width * scale))
        resized_height = max(1, int(cropped.height * scale))

        resampling = getattr(Image, "Resampling", Image).LANCZOS
        resized = cropped.resize((resized_width, resized_height), resampling)
        canvas = Image.new("RGBA", (target_size, target_size), (0, 0, 0, 0))
        paste_x = (target_size - resized_width) // 2
        paste_y = (target_size - resized_height) // 2
        canvas.paste(resized, (paste_x, paste_y), resized)

        buffer = io.BytesIO()
        canvas.save(buffer, format="PNG", optimize=True)

    output = ContentFile(buffer.getvalue())
    output.name = f"{image_path.stem}_acc_norm.png"
    return output


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def accessory_process(request):
    image = request.FILES.get("image")
    if not image:
        return Response({"error": "Image required"}, status=400)

    try:
        segmented_path = segment_image(image)
        segmented_url = request.build_absolute_uri(segmented_path)
    except Exception:
        return Response({"error": "Segmentation failed"}, status=500)

    image_path = _resolve_segmented_path(segmented_url)
    if not image_path.exists():
        return Response({"error": "Segmented file missing"}, status=500)

    colors = _extract_colors_safe(image_path)
    return Response(
        {
            "segmented_image": segmented_url,
            "dominant_color": colors.get("dominant_color", UNKNOWN_COLORS["dominant_color"]),
            "secondary_color": colors.get("secondary_color", UNKNOWN_COLORS["secondary_color"]),
        },
        status=200,
    )


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def accessory_save(request):
    data = request.data
    segmented_url = data.get("segmented_image")
    storage_id = data.get("storage_unit")

    if not segmented_url or not storage_id:
        return Response({"error": "segmented_image and storage_unit required"}, status=400)

    name = (data.get("name") or "").strip()
    if not name:
        return Response({"error": "name required"}, status=400)

    image_path = _resolve_segmented_path(segmented_url)
    if not image_path.exists():
        return Response({"error": "Image missing"}, status=400)

    try:
        storage = StorageUnit.objects.get(id=storage_id, user=request.user)
    except StorageUnit.DoesNotExist:
        return Response({"error": "Invalid storage unit"}, status=400)

    normalized_image = _normalize_segmented_image(image_path)

    accessory = AccessoryItem.objects.create(
        user=request.user,
        storage_unit=storage,
        image=File(normalized_image, name=normalized_image.name),
        name=name,
        description=data.get("description") or "",
        dominant_color=data.get("dominant_color") or UNKNOWN_COLORS["dominant_color"],
        secondary_color=data.get("secondary_color"),
    )
    try:
        os.remove(image_path)
    except Exception:
        pass

    return Response({"id": accessory.id}, status=201)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def list_accessories(request):
    items = AccessoryItem.objects.filter(user=request.user).order_by("-created_at")
    serializer = AccessoryItemSerializer(items, many=True, context={"request": request})
    return Response(serializer.data, status=200)


@api_view(["GET", "PUT", "DELETE"])
@permission_classes([IsAuthenticated])
def accessory_detail(request, pk):
    try:
        item = AccessoryItem.objects.get(id=pk, user=request.user)
    except AccessoryItem.DoesNotExist:
        return Response({"error": "Not found"}, status=404)

    if request.method == "GET":
        serializer = AccessoryItemSerializer(item, context={"request": request})
        return Response(serializer.data, status=200)

    if request.method == "DELETE":
        item.image.delete(save=False)
        item.delete()
        return Response(status=204)

    if "name" in request.data:
        name = (request.data.get("name") or "").strip()
        if not name:
            return Response({"error": "Name is required"}, status=400)
        item.name = name

    if "description" in request.data:
        item.description = request.data.get("description") or ""

    if "storage_unit" in request.data:
        storage_id = request.data.get("storage_unit")
        try:
            storage = StorageUnit.objects.get(id=storage_id, user=request.user)
        except StorageUnit.DoesNotExist:
            return Response({"error": "Invalid storage unit"}, status=400)
        item.storage_unit = storage

    item.save()
    serializer = AccessoryItemSerializer(item, context={"request": request})
    return Response(serializer.data, status=200)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def toggle_accessory_favourite(request, pk):
    try:
        item = AccessoryItem.objects.get(id=pk, user=request.user)
    except AccessoryItem.DoesNotExist:
        return Response({"error": "Not found"}, status=404)

    item.is_favourite = not item.is_favourite
    item.save(update_fields=["is_favourite"])
    return Response({"id": item.id, "is_favourite": item.is_favourite}, status=200)
