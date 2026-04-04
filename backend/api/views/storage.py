from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.core.exceptions import ValidationError

from ..models import StorageUnit, ClothingItem, NonClothingItem
from ..serializer import StorageUnitSerializer


def _as_bool(value):
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.lower() in ['true', '1', 'yes', 'on']
    return bool(value)

def get_recursive_storage_ids(storage):
    ids = [storage.id]

    for child in storage.sub_units.all():
        ids += get_recursive_storage_ids(child)

    return ids


@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def list_storage_units(request):
    if request.method == 'POST':
        parent_id = request.data.get('parent_storage')
        parent = None

        if parent_id:
            try:
                parent = StorageUnit.objects.get(id=parent_id, user=request.user)
            except StorageUnit.DoesNotExist:
                return Response({"error": "Invalid parent storage"}, status=400)

        storage = StorageUnit(
            user=request.user,
            name=request.data.get('name', '').strip(),
            type=request.data.get('type', ''),
            description=request.data.get('description'),
            parent_storage=parent,
            is_put_away=_as_bool(request.data.get('is_put_away', False)),
        )

        try:
            storage.save()
        except ValidationError as e:
            return Response({"error": e.message_dict if hasattr(e, "message_dict") else e.messages}, status=400)

        return Response(StorageUnitSerializer(storage).data, status=201)

    storages = StorageUnit.objects.filter(user=request.user)
    serializer = StorageUnitSerializer(storages, many=True)

    return Response(serializer.data)


@api_view(['PUT', 'DELETE'])
@permission_classes([IsAuthenticated])
def storage_detail(request, pk):
    try:
        storage = StorageUnit.objects.get(id=pk, user=request.user)
    except StorageUnit.DoesNotExist:
        return Response({"error": "Storage not found"}, status=404)

    if request.method == 'DELETE':
        if storage.clothes.exists() or storage.sub_units.exists():
            return Response(
                {"error": "Cannot delete storage that has items or sub-storages"},
                status=400,
            )
        storage.delete()
        return Response(status=204)

    parent_id = request.data.get('parent_storage')
    if parent_id is not None:
        if parent_id == '':
            storage.parent_storage = None
        else:
            try:
                parent = StorageUnit.objects.get(id=parent_id, user=request.user)
            except StorageUnit.DoesNotExist:
                return Response({"error": "Invalid parent storage"}, status=400)

            if parent.id == storage.id:
                return Response({"error": "Storage cannot be its own parent"}, status=400)

            storage.parent_storage = parent

    if 'name' in request.data:
        storage.name = request.data.get('name', '').strip()
    if 'type' in request.data:
        storage.type = request.data.get('type', '')
    if 'description' in request.data:
        storage.description = request.data.get('description')
    if 'is_put_away' in request.data:
        storage.is_put_away = _as_bool(request.data.get('is_put_away'))

    try:
        storage.save()
    except ValidationError as e:
        return Response({"error": e.message_dict if hasattr(e, "message_dict") else e.messages}, status=400)

    return Response(StorageUnitSerializer(storage).data)

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def storage_view(request, pk):

    try:
        storage = StorageUnit.objects.get(id=pk, user=request.user)
    except StorageUnit.DoesNotExist:
        return Response({"error": "Not found"}, status=404)

    recursive_ids = get_recursive_storage_ids(storage)

    clothes = ClothingItem.objects.filter(
        user=request.user,
        storage_unit__in=recursive_ids
    )

    non_clothes = NonClothingItem.objects.filter(
        storage_unit__in=recursive_ids
    )

    return Response({
        "storage": StorageUnitSerializer(storage).data,

        "counts": {
            "clothing": clothes.count(),
            "non_clothing": non_clothes.count(),
            "total": clothes.count() + non_clothes.count(),
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
        ]
    })
