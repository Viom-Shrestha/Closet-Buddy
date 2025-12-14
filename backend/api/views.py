from django.shortcuts import render
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser
from .models import ClothingItem
from .serializer import RegisterSerializer
from rest_framework_simplejwt.tokens import RefreshToken

from django.conf import settings
from pathlib import Path
from rest_framework import generics
from django.contrib.auth.models import User

from rest_framework.permissions import IsAuthenticated
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from ai_models.segmentation.segmentation_utill import segment_image
# from .segmentation_utils import segment_image
# from .classification_utils import classify_item, extract_color

class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = RegisterSerializer

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def profile(request):
    user = request.user
    role = "admin" if user.is_staff else "user"

    return Response({
        "username": user.username,
        "email": user.email,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "role": role,
    })

# Admin-only route
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def admin_dashboard(request):
    user = request.user
    if not user.is_staff:
        return Response({"detail": "You do not have permission to access this."}, status=403)

    # Example data for admin
    return Response({
        "message": f"Welcome Admin {user.username}",
        "total_users": user.__class__.objects.count(),
    })

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def segment_clothing(request):
    image = request.FILES.get('image')

    if not image:
        return Response({"error": "No image provided"}, status=400)

    segmented_url = segment_image(image)

    return Response({
        "segmented_image": segmented_url
    })

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def logout(request):
    try:
        refresh_token = request.data.get("refresh")
        token = RefreshToken(refresh_token)
        token.blacklist()
    except Exception:
        pass

    return Response({"detail": "Logged out"})

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def delete_segmented_image(request):
    """
    Deletes a segmented image file given its URL path.
    """
    # Expecting the relative path like '/media/segmented/image.png'
    segmented_url = request.data.get('url') 

    if not segmented_url:
        return Response({"detail": "URL not provided."}, status=400)
    
    try:
        # Strip the MEDIA_URL prefix to get the path relative to MEDIA_ROOT
        relative_path = segmented_url.lstrip(settings.MEDIA_URL)
        
        # Construct the absolute file system path
        file_path = Path(settings.MEDIA_ROOT) / relative_path

        if file_path.exists():
            file_path.unlink() # Delete the file
            return Response({"detail": "File deleted successfully."}, status=200)
        else:
            # File might have already been deleted or URL was invalid
            return Response({"detail": "File not found."}, status=200) 
            
    except Exception as e:
        print(f"Error during file deletion: {e}")
        return Response({"detail": "Failed to delete file."}, status=500)