from drf_spectacular.utils import extend_schema, extend_schema_view
from rest_framework import status, viewsets
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from ..models import NonClothingItem
from ..serializer import NonClothingItemSerializer


@extend_schema_view(
    create=extend_schema(summary="Create non-clothing item"),
    list=extend_schema(summary="List non-clothing items"),
    retrieve=extend_schema(summary="Get non-clothing detail"),
    update=extend_schema(summary="Update non-clothing item"),
    destroy=extend_schema(summary="Delete non-clothing item"),
)
class NonClothingViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = NonClothingItemSerializer

    def get_queryset(self):
        return NonClothingItem.objects.filter(user=self.request.user)

    def _get_item(self, pk):
        try:
            return self.get_queryset().get(id=pk)
        except NonClothingItem.DoesNotExist:
            return None

    def create(self, request):
        item = NonClothingItem.objects.create(
            user=request.user,
            storage_unit_id=request.data["storage_id"],
            name=request.data["name"],
            description=request.data.get("description", ""),
        )
        return Response(NonClothingItemSerializer(item).data, status=status.HTTP_201_CREATED)

    def list(self, request):
        items = self.get_queryset()
        return Response(NonClothingItemSerializer(items, many=True).data, status=status.HTTP_200_OK)

    def retrieve(self, request, pk=None):
        item = self._get_item(pk)
        if not item:
            return Response({"error": "Not found"}, status=status.HTTP_404_NOT_FOUND)

        return Response(NonClothingItemSerializer(item).data, status=status.HTTP_200_OK)

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

        item.save()
        return Response(NonClothingItemSerializer(item).data, status=status.HTTP_200_OK)

    def destroy(self, request, pk=None):
        item = self._get_item(pk)
        if not item:
            return Response({"error": "Not found"}, status=status.HTTP_404_NOT_FOUND)

        item.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
