from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from django.db.models import F
from django.utils import timezone
from typing import Optional

from ..models import AccessoryItem, ClothingItem, Outfit
from ..recommend import scoring
from ..serializer import OutfitReadSerializer, OutfitWriteSerializer


def _parse_bool(value) -> Optional[bool]:
    if value is None:
        return None
    if isinstance(value, bool):
        return value

    normalized = str(value).strip().lower()
    if normalized in {"true", "1", "yes", "on"}:
        return True
    if normalized in {"false", "0", "no", "off"}:
        return False
    return None


def _get_user_outfit_or_404(user, pk):
    try:
        return Outfit.objects.get(id=pk, user=user)
    except Outfit.DoesNotExist:
        return None


def _parse_int(value, field_name: str) -> Optional[int]:
    if value in [None, ""]:
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        raise ValueError(f"{field_name} must be an integer.")


def _get_user_clothing_or_error(user, item_id: int, field_name: str) -> ClothingItem:
    try:
        return ClothingItem.objects.get(id=item_id, user=user)
    except ClothingItem.DoesNotExist:
        raise ValueError(f"{field_name} must belong to current user.")


def _get_user_accessories_or_error(user, accessory_ids):
    if not accessory_ids:
        return []
    found = list(AccessoryItem.objects.filter(user=user, id__in=accessory_ids))
    found_ids = {item.id for item in found}
    missing = [acc_id for acc_id in accessory_ids if acc_id not in found_ids]
    if missing:
        raise ValueError("All accessory_ids must belong to current user.")
    return found


@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def outfits(request):
    if request.method == "GET":
        queryset = Outfit.objects.filter(user=request.user)
        favourite = request.GET.get("is_favourite")
        if favourite is not None:
            parsed_favourite = _parse_bool(favourite)
            if parsed_favourite is None:
                return Response(
                    {"error": "is_favourite must be a boolean value."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            queryset = queryset.filter(is_favourite=parsed_favourite)

        queryset = queryset.order_by("-created_at")
        serializer = OutfitReadSerializer(queryset, many=True, context={"request": request})
        return Response(serializer.data, status=status.HTTP_200_OK)

    serializer = OutfitWriteSerializer(data=request.data, context={"request": request})
    if not serializer.is_valid():
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    outfit = serializer.save(user=request.user)
    read_serializer = OutfitReadSerializer(outfit, context={"request": request})
    return Response(read_serializer.data, status=status.HTTP_201_CREATED)


@api_view(["GET", "PUT", "PATCH", "DELETE"])
@permission_classes([IsAuthenticated])
def outfit_detail(request, pk):
    outfit = _get_user_outfit_or_404(request.user, pk)
    if not outfit:
        return Response({"error": "Not found"}, status=status.HTTP_404_NOT_FOUND)

    if request.method == "GET":
        serializer = OutfitReadSerializer(outfit, context={"request": request})
        return Response(serializer.data, status=status.HTTP_200_OK)

    if request.method in ["PUT", "PATCH"]:
        serializer = OutfitWriteSerializer(
            outfit,
            data=request.data,
            partial=request.method == "PATCH",
            context={"request": request},
        )
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        saved = serializer.save()
        read_serializer = OutfitReadSerializer(saved, context={"request": request})
        return Response(read_serializer.data, status=status.HTTP_200_OK)

    outfit.delete()
    return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def toggle_outfit_favourite(request, pk):
    outfit = _get_user_outfit_or_404(request.user, pk)
    if not outfit:
        return Response({"error": "Not found"}, status=status.HTTP_404_NOT_FOUND)

    outfit.is_favourite = not outfit.is_favourite
    outfit.save(update_fields=["is_favourite"])

    serializer = OutfitReadSerializer(outfit, context={"request": request})
    return Response(serializer.data, status=status.HTTP_200_OK)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def rate_outfit_ai(request):
    data = request.data or {}

    try:
        topwear_id = _parse_int(data.get("topwear_id"), "topwear_id")
        bottomwear_id = _parse_int(data.get("bottomwear_id"), "bottomwear_id")
        shoes_id = _parse_int(data.get("shoes_id"), "shoes_id")
        outerwear_id = _parse_int(data.get("outerwear_id"), "outerwear_id")
        outfit_id = _parse_int(data.get("outfit_id"), "outfit_id")
    except ValueError as exc:
        return Response({"error": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

    if not topwear_id or not bottomwear_id or not shoes_id:
        return Response(
            {"error": "topwear_id, bottomwear_id, and shoes_id are required."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    accessory_ids_raw = data.get("accessory_ids", [])
    if accessory_ids_raw in [None, ""]:
        accessory_ids_raw = []
    if not isinstance(accessory_ids_raw, list):
        return Response({"error": "accessory_ids must be a list."}, status=status.HTTP_400_BAD_REQUEST)

    accessory_ids = []
    try:
        for index, raw in enumerate(accessory_ids_raw):
            parsed = _parse_int(raw, f"accessory_ids[{index}]")
            if parsed is None:
                raise ValueError(f"accessory_ids[{index}] must be an integer.")
            accessory_ids.append(parsed)

        topwear = _get_user_clothing_or_error(request.user, topwear_id, "topwear_id")
        bottomwear = _get_user_clothing_or_error(request.user, bottomwear_id, "bottomwear_id")
        shoes = _get_user_clothing_or_error(request.user, shoes_id, "shoes_id")
        outerwear = None
        if outerwear_id is not None:
            outerwear = _get_user_clothing_or_error(request.user, outerwear_id, "outerwear_id")
        _get_user_accessories_or_error(request.user, accessory_ids)
    except ValueError as exc:
        return Response({"error": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

    outfit_payload = {
        "topwear": topwear,
        "bottomwear": bottomwear,
        "shoes": shoes,
        "outerwear": outerwear,
    }
    ai_snapshot = scoring.ai_rating_snapshot(outfit_payload)
    rated_at = timezone.now()
    ai_snapshot["ai_rated_at"] = rated_at.isoformat()

    if outfit_id is not None:
        outfit = _get_user_outfit_or_404(request.user, outfit_id)
        if not outfit:
            return Response({"error": "Outfit not found"}, status=status.HTTP_404_NOT_FOUND)

        outfit.ai_rating_score = ai_snapshot["ai_rating_score"]
        outfit.ai_rating_reasons = ai_snapshot["ai_rating_reasons"]
        outfit.ai_rating_breakdown = ai_snapshot["ai_rating_breakdown"]
        outfit.ai_rated_at = rated_at
        outfit.save(
            update_fields=[
                "ai_rating_score",
                "ai_rating_reasons",
                "ai_rating_breakdown",
                "ai_rated_at",
            ]
        )
        ai_snapshot["outfit_id"] = outfit.id

    return Response(ai_snapshot, status=status.HTTP_200_OK)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def mark_outfit_worn(request, pk):
    outfit = _get_user_outfit_or_404(request.user, pk)
    if not outfit:
        return Response({"error": "Not found"}, status=status.HTTP_404_NOT_FOUND)

    today = timezone.localdate()
    if outfit.last_worn_at and outfit.last_worn_at.date() == today:
        serializer = OutfitReadSerializer(outfit, context={"request": request})
        return Response(serializer.data, status=status.HTTP_200_OK)

    Outfit.objects.filter(id=outfit.id).update(
        wear_count=F("wear_count") + 1,
        last_worn_at=timezone.now(),
    )
    outfit.refresh_from_db(fields=["wear_count", "last_worn_at"])

    serializer = OutfitReadSerializer(outfit, context={"request": request})
    return Response(serializer.data, status=status.HTTP_200_OK)
