from django.contrib.auth.models import User
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def admin_dashboard(request):

    if not request.user.is_staff:
        return Response({"detail": "Permission denied"}, status=403)

    return Response({
        "total_users": User.objects.count()
    })
