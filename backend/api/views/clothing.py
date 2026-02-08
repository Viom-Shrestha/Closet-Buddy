
import os
from pathlib import Path
from urllib.parse import urlparse

from django.conf import settings
from django.core.files import File

from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from ..models import ClothingItem, StorageUnit
from ..serializer import ClothingItemCreateSerializer

from ai_models.segmentation.segmentation_utill import segment_image
from ai_models.utils.auth_util import is_clothing
from ai_models.utils.color_extraction_util import extract_colors_with_names


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def clothing_process(request):

    image = request.FILES.get("image")

    if not image:
        return Response({"error": "Image required"}, status=400)

    # -------- CLIP --------
    if not is_clothing(image.file):
        return Response({"error": "Not clothing"}, status=400)

    # -------- SEGMENT --------
    try:
        segmented_url = segment_image(image)
    except Exception:
        return Response({"error": "Segmentation failed"}, status=500)

    parsed = urlparse(segmented_url)
    relative = parsed.path.replace(settings.MEDIA_URL, "")
    image_path = Path(settings.MEDIA_ROOT) / relative
    
    if not image_path.exists():
        return Response({"error": "Segmented file missing"}, status=500)

    # -------- COLORS --------
    try:
        colors = extract_colors_with_names(str(image_path))
    except Exception:
        colors = {"dominant_color": "Unknown", "secondary_color": "Unknown"}

    # -------- TEMP CLASSIFICATION --------
    result = {
        "segmented_image": segmented_url,
        "dominant_color": colors.get("dominant_color", "Unknown"),
        "secondary_color": colors.get("secondary_color", "Unknown"),
        "category": "Topwear",
        "subcategory": "Shirt",
        "occasion": "Casual"
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

    parsed = urlparse(segmented_url)
    relative = parsed.path.replace(settings.MEDIA_URL, "")
    image_path = Path(settings.MEDIA_ROOT) / relative

    if not image_path.exists():
        return Response({"error": "Image missing"}, status=400)

    try:
        storage = StorageUnit.objects.get(id=storage_id, user=request.user)
    except StorageUnit.DoesNotExist:
        return Response({"error": "Invalid storage unit"}, status=400)

    with open(image_path, "rb") as f:
        clothing = ClothingItem.objects.create(
            user=request.user,
            storage_unit=storage,
            image=File(f, name=image_path.name),
            dominant_color=data["dominant_color"],
            secondary_color=data.get("secondary_color"),
            category=data["category"],
            subcategory=data["subcategory"],
            occasion=data["occasion"]
        )

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



