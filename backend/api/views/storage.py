from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from ..models import StorageUnit
from ..serializer import StorageUnitSerializer


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def list_storage_units(request):

    storages = StorageUnit.objects.filter(user=request.user)
    serializer = StorageUnitSerializer(storages, many=True)

    return Response(serializer.data)
