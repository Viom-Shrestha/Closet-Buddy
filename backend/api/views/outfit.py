from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from django.db.models import F
from django.utils import timezone

from ..models import Outfit
from ..serializer import OutfitReadSerializer, OutfitWriteSerializer


def _get_user_outfit_or_404(user, pk):
    try:
        return Outfit.objects.get(id=pk, user=user)
    except Outfit.DoesNotExist:
        return None


@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def outfits(request):
    if request.method == "GET":
        queryset = Outfit.objects.filter(user=request.user).order_by("-created_at")
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
