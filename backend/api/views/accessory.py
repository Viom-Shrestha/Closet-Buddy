import io
import os
from pathlib import Path
from urllib.parse import urlparse

from django.conf import settings
from django.core.files import File
from django.core.files.base import ContentFile
from PIL import Image
from drf_spectacular.utils import extend_schema
from rest_framework import serializers, status, viewsets
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from ai_models.segmentation.segmentation_utill import segment_image
from ai_models.utils.color_extraction_util import extract_colors_with_names

from ..models import AccessoryItem, StorageUnit
from ..serializer import AccessoryItemSerializer

UNKNOWN_COLORS = {"dominant_color": "Unknown", "secondary_color": "Unknown"}


class AccessoryProcessRequestSerializer(serializers.Serializer):
    image = serializers.ImageField(required=True)


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


class AccessoryViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = AccessoryItemSerializer

    def get_queryset(self):
        return AccessoryItem.objects.filter(user=self.request.user)

    def _get_item(self, pk):
        try:
            return self.get_queryset().get(id=pk)
        except AccessoryItem.DoesNotExist:
            return None

    @extend_schema(
        summary="Process accessory image",
        request={"multipart/form-data": AccessoryProcessRequestSerializer},
    )
    def process(self, request):
        image = request.FILES.get("image")
        if not image:
            return Response({"error": "Image required"}, status=status.HTTP_400_BAD_REQUEST)

        try:
            segmented_path = segment_image(image)
            segmented_url = request.build_absolute_uri(segmented_path)
        except Exception:
            return Response({"error": "Segmentation failed"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        image_path = _resolve_segmented_path(segmented_url)
        if not image_path.exists():
            return Response({"error": "Segmented file missing"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        colors = _extract_colors_safe(image_path)
        return Response(
            {
                "segmented_image": segmented_url,
                "dominant_color": colors.get("dominant_color", UNKNOWN_COLORS["dominant_color"]),
                "secondary_color": colors.get("secondary_color", UNKNOWN_COLORS["secondary_color"]),
            },
            status=status.HTTP_200_OK,
        )

    @extend_schema(summary="Save processed accessory")
    def save(self, request):
        data = request.data
        segmented_url = data.get("segmented_image")
        storage_id = data.get("storage_unit")

        if not segmented_url or not storage_id:
            return Response({"error": "segmented_image and storage_unit required"}, status=status.HTTP_400_BAD_REQUEST)

        name = (data.get("name") or "").strip()
        if not name:
            return Response({"error": "name required"}, status=status.HTTP_400_BAD_REQUEST)

        image_path = _resolve_segmented_path(segmented_url)
        if not image_path.exists():
            return Response({"error": "Image missing"}, status=status.HTTP_400_BAD_REQUEST)

        try:
            storage = StorageUnit.objects.get(id=storage_id, user=request.user)
        except StorageUnit.DoesNotExist:
            return Response({"error": "Invalid storage unit"}, status=status.HTTP_400_BAD_REQUEST)

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

        return Response({"id": accessory.id}, status=status.HTTP_201_CREATED)

    @extend_schema(summary="List all accessories")
    def all(self, request):
        items = self.get_queryset().order_by("-created_at")
        serializer = AccessoryItemSerializer(items, many=True, context={"request": request})
        return Response(serializer.data, status=status.HTTP_200_OK)

    @extend_schema(summary="Get accessory detail")
    def retrieve(self, request, pk=None):
        item = self._get_item(pk)
        if not item:
            return Response({"error": "Not found"}, status=status.HTTP_404_NOT_FOUND)

        serializer = AccessoryItemSerializer(item, context={"request": request})
        return Response(serializer.data, status=status.HTTP_200_OK)

    @extend_schema(summary="Update accessory")
    def update(self, request, pk=None):
        item = self._get_item(pk)
        if not item:
            return Response({"error": "Not found"}, status=status.HTTP_404_NOT_FOUND)

        if "name" in request.data:
            name = (request.data.get("name") or "").strip()
            if not name:
                return Response({"error": "Name is required"}, status=status.HTTP_400_BAD_REQUEST)
            item.name = name

        if "description" in request.data:
            item.description = request.data.get("description") or ""

        if "storage_unit" in request.data:
            storage_id = request.data.get("storage_unit")
            try:
                storage = StorageUnit.objects.get(id=storage_id, user=request.user)
            except StorageUnit.DoesNotExist:
                return Response({"error": "Invalid storage unit"}, status=status.HTTP_400_BAD_REQUEST)
            item.storage_unit = storage

        item.save()
        serializer = AccessoryItemSerializer(item, context={"request": request})
        return Response(serializer.data, status=status.HTTP_200_OK)

    @extend_schema(summary="Delete accessory")
    def destroy(self, request, pk=None):
        item = self._get_item(pk)
        if not item:
            return Response({"error": "Not found"}, status=status.HTTP_404_NOT_FOUND)

        item.image.delete(save=False)
        item.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

    @extend_schema(summary="Toggle accessory favourite", request=None)
    def toggle_favourite(self, request, pk=None):
        item = self._get_item(pk)
        if not item:
            return Response({"error": "Not found"}, status=status.HTTP_404_NOT_FOUND)

        item.is_favourite = not item.is_favourite
        item.save(update_fields=["is_favourite"])
        return Response({"id": item.id, "is_favourite": item.is_favourite}, status=status.HTTP_200_OK)
