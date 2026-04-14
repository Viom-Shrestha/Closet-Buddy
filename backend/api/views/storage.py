from django.core.exceptions import ValidationError
from drf_spectacular.utils import extend_schema
from rest_framework import serializers, status, viewsets
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from ..models import ClothingItem, NonClothingItem, StorageUnit
from ..serializer import StorageUnitSerializer

STORAGE_TYPE_CHOICES = StorageUnit.STORAGE_TYPE_CHOICES


class StorageUnitCreateRequestSerializer(serializers.Serializer):
    name = serializers.CharField(max_length=100)
    type = serializers.ChoiceField(choices=STORAGE_TYPE_CHOICES)
    parent_storage = serializers.IntegerField(required=False, allow_null=True)
    is_put_away = serializers.BooleanField(required=False, default=False)


class StorageUnitUpdateRequestSerializer(serializers.Serializer):
    name = serializers.CharField(max_length=100, required=False, allow_blank=True)
    type = serializers.ChoiceField(choices=STORAGE_TYPE_CHOICES, required=False)
    parent_storage = serializers.CharField(
        required=False,
        allow_blank=True,
        allow_null=True,
        help_text="Use storage id, null, or empty string to clear parent.",
    )
    is_put_away = serializers.BooleanField(required=False)


class ErrorResponseSerializer(serializers.Serializer):
    error = serializers.JSONField()


def _as_bool(value):
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.lower() in ["true", "1", "yes", "on"]
    return bool(value)


def get_recursive_storage_ids(storage):
    ids = [storage.id]

    for child in storage.sub_units.all():
        ids += get_recursive_storage_ids(child)

    return ids


class StorageUnitViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = StorageUnitSerializer

    def get_queryset(self):
        return StorageUnit.objects.filter(user=self.request.user)

    def _get_storage(self, pk):
        try:
            return self.get_queryset().get(id=pk)
        except StorageUnit.DoesNotExist:
            return None

    @extend_schema(
        summary="List storage units",
        responses={200: StorageUnitSerializer(many=True)},
    )
    def list(self, request):
        storages = self.get_queryset()
        serializer = StorageUnitSerializer(storages, many=True, context={"request": request})
        return Response(serializer.data, status=status.HTTP_200_OK)

    @extend_schema(
        summary="Create storage unit",
        request=StorageUnitCreateRequestSerializer,
        responses={201: StorageUnitSerializer, 400: ErrorResponseSerializer},
    )
    def create(self, request):
        parent_id = request.data.get("parent_storage")
        parent = None
        if parent_id:
            try:
                parent = StorageUnit.objects.get(id=parent_id, user=request.user)
            except StorageUnit.DoesNotExist:
                return Response({"error": "Invalid parent storage"}, status=status.HTTP_400_BAD_REQUEST)

        storage = StorageUnit(
            user=request.user,
            name=(request.data.get("name", "") or "").strip(),
            type=request.data.get("type", ""),
            parent_storage=parent,
            is_put_away=_as_bool(request.data.get("is_put_away", False)),
        )

        try:
            storage.save()
        except ValidationError as exc:
            detail = exc.message_dict if hasattr(exc, "message_dict") else exc.messages
            return Response({"error": detail}, status=status.HTTP_400_BAD_REQUEST)

        serializer = StorageUnitSerializer(storage, context={"request": request})
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @extend_schema(
        summary="Update storage unit",
        request=StorageUnitUpdateRequestSerializer,
        responses={200: StorageUnitSerializer, 400: ErrorResponseSerializer, 404: ErrorResponseSerializer},
    )
    def update(self, request, pk=None):
        storage = self._get_storage(pk)
        if not storage:
            return Response({"error": "Storage not found"}, status=status.HTTP_404_NOT_FOUND)

        parent_id = request.data.get("parent_storage")
        if parent_id is not None:
            if parent_id == "":
                storage.parent_storage = None
            else:
                try:
                    parent = StorageUnit.objects.get(id=parent_id, user=request.user)
                except StorageUnit.DoesNotExist:
                    return Response({"error": "Invalid parent storage"}, status=status.HTTP_400_BAD_REQUEST)

                if parent.id == storage.id:
                    return Response({"error": "Storage cannot be its own parent"}, status=status.HTTP_400_BAD_REQUEST)

                storage.parent_storage = parent

        if "name" in request.data:
            storage.name = (request.data.get("name", "") or "").strip()
        if "type" in request.data:
            storage.type = request.data.get("type", "")
        if "is_put_away" in request.data:
            storage.is_put_away = _as_bool(request.data.get("is_put_away"))

        try:
            storage.save()
        except ValidationError as exc:
            detail = exc.message_dict if hasattr(exc, "message_dict") else exc.messages
            return Response({"error": detail}, status=status.HTTP_400_BAD_REQUEST)

        serializer = StorageUnitSerializer(storage, context={"request": request})
        return Response(serializer.data, status=status.HTTP_200_OK)

    @extend_schema(
        summary="Delete storage unit",
        responses={204: None, 400: ErrorResponseSerializer, 404: ErrorResponseSerializer},
    )
    def destroy(self, request, pk=None):
        storage = self._get_storage(pk)
        if not storage:
            return Response({"error": "Storage not found"}, status=status.HTTP_404_NOT_FOUND)

        if storage.clothes.exists() or storage.sub_units.exists():
            return Response(
                {"error": "Cannot delete storage that has items or sub-storages"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        storage.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

    @extend_schema(summary="View storage contents")
    def view(self, request, pk=None):
        storage = self._get_storage(pk)
        if not storage:
            return Response({"error": "Not found"}, status=status.HTTP_404_NOT_FOUND)

        recursive_ids = get_recursive_storage_ids(storage)

        clothes = ClothingItem.objects.filter(
            user=request.user,
            storage_unit__in=recursive_ids,
        )

        non_clothes = NonClothingItem.objects.filter(
            storage_unit__in=recursive_ids,
        )

        clothing_count = clothes.count()
        non_clothing_count = non_clothes.count()

        return Response(
            {
                "storage": StorageUnitSerializer(storage, context={"request": request}).data,
                "counts": {
                    "clothing": clothing_count,
                    "non_clothing": non_clothing_count,
                    "total": clothing_count + non_clothing_count,
                },
                "clothes": [
                    {
                        "id": c.id,
                        "image": request.build_absolute_uri(c.image.url),
                        "category": c.category,
                        "subcategory": c.subcategory,
                        "occasion": c.occasion,
                        "dominant_color": c.dominant_color,
                        "attributes": c.attributes,
                        "is_favourite": c.is_favourite,
                        "storage_unit": {
                            "id": c.storage_unit.id,
                            "name": c.storage_unit.name,
                            "type": c.storage_unit.type,
                        },
                    }
                    for c in clothes
                ],
                "non_clothing_items": [
                    {
                        "id": n.id,
                        "name": n.name,
                        "description": n.description,
                    }
                    for n in non_clothes
                ],
            },
            status=status.HTTP_200_OK,
        )
