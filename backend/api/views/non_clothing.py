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
