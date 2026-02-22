from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from ..models import NonClothingItem
from ..serializer import NonClothingItemSerializer


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def save_non_clothing_item(request):

    item = NonClothingItem.objects.create(
        user=request.user,
        storage_unit_id=request.data["storage_id"],
        name=request.data["name"],
        description=request.data.get("description", "")
    )

    return Response(NonClothingItemSerializer(item).data, status=201)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def list_non_clothing_items(request):

    items = NonClothingItem.objects.filter(user=request.user)
    return Response(NonClothingItemSerializer(items, many=True).data)


@api_view(['PUT', 'DELETE'])
@permission_classes([IsAuthenticated])
def non_clothing_detail(request, pk):
    try:
        item = NonClothingItem.objects.get(id=pk, user=request.user)
    except NonClothingItem.DoesNotExist:
        return Response({"error": "Not found"}, status=404)

    if request.method == 'DELETE':
        item.delete()
        return Response(status=204)

    if 'name' in request.data:
        name = (request.data.get('name') or '').strip()
        if not name:
            return Response({"error": "Name is required"}, status=400)
        item.name = name

    if 'description' in request.data:
        item.description = request.data.get('description') or ''

    item.save()
    return Response(NonClothingItemSerializer(item).data, status=200)
