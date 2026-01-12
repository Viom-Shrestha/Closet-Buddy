from django.contrib.auth.models import User
from django.conf import settings
from pathlib import Path

from rest_framework import generics
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework_simplejwt.tokens import RefreshToken

from .models import ClothingItem, StorageUnit, NonClothingItem
from .serializer import RegisterSerializer, ClothingItemCreateSerializer,StorageUnitSerializer, NonClothingItemSerializer
from ai_models.segmentation.segmentation_utill import segment_image
from ai_models.utils.color_extraction_util import extract_colors_with_names
import os

# ------------------- AUTH -------------------

class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = RegisterSerializer

@api_view(['GET', 'PUT']) # Added PUT here
@permission_classes([IsAuthenticated])
def profile(request):
    user = request.user
    
    if request.method == 'GET':
        role = "admin" if user.is_staff else "user"
        return Response({
            "username": user.username,
            "email": user.email,
            "first_name": user.first_name,
            "last_name": user.last_name,
            "role": role,
        })

    elif request.method == 'PUT':
        # Get data from the Flutter request body
        first_name = request.data.get('first_name')
        last_name = request.data.get('last_name')

        if not first_name or not last_name:
            return Response(
                {"error": "First name and last name cannot be empty"}, 
            )
        
        # Check for name length (optional but good)
        if len(first_name) > 30 or len(last_name) > 30:
            return Response(
                {"error": "Name is too long"}, 
            )
            
        # Update fields if they were provided
        user.first_name = first_name
        user.last_name = last_name
        
        user.save()

        return Response({
            "message": "Profile updated successfully",
            "first_name": user.first_name,
            "last_name": user.last_name,
        }, status=200)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def logout(request):
    """Blacklist JWT refresh token"""
    try:
        refresh_token = request.data.get("refresh")
        token = RefreshToken(refresh_token)
        token.blacklist()
    except Exception:
        pass
    return Response({"detail": "Logged out"})


# ------------------- ADMIN -------------------

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def admin_dashboard(request):
    """Admin-only dashboard data"""
    user = request.user
    if not user.is_staff:
        return Response({"detail": "Permission denied."}, status=403)

    return Response({
        "message": f"Welcome Admin {user.username}",
        "total_users": User.objects.count(),
    })


# ------------------- CLOTHING ITEM -------------------

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def segment_clothing(request):
    """Segment clothing image"""
    image = request.FILES.get('image')
    if not image:
        return Response({"error": "No image provided"}, status=400)

    segmented_url = segment_image(image)
    return Response({"segmented_image": segmented_url})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def delete_segmented_image(request):
    segmented_url = request.data.get('url') or request.data.get('segmented_image')
    
    if not segmented_url:
        return Response({"detail": "URL not provided."}, status=400)

    try:
        media_url = settings.MEDIA_URL 
        if media_url in segmented_url:
            relative_path = segmented_url.split(media_url)[-1]
        else:
            relative_path = segmented_url

        file_path = os.path.join(settings.MEDIA_ROOT, relative_path)
        print(f"DEBUG: Attempting to delete file at: {file_path}")

        if os.path.exists(file_path):
            os.remove(file_path)
            return Response({"detail": "File deleted successfully."}, status=200)
        else:
            print(f"DEBUG: File not found at {file_path}")
            return Response({"detail": "File not found on server."}, status=404)

    except Exception as e:
        print(f"DEBUG: Deletion Error: {str(e)}")
        return Response({"detail": f"Error: {str(e)}"}, status=500)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def save_clothing_item(request):
    data = request.data.copy()
    segmented_url = data.get('image_url')

    if segmented_url:
        media_url = settings.MEDIA_URL
        relative_path = segmented_url.split(media_url)[-1]
        full_path = os.path.join(settings.MEDIA_ROOT, relative_path)

        if os.path.exists(full_path):
            f = open(full_path, 'rb')
            # 'image' matches your model field name
            request.FILES['image'] = File(f, name=os.path.basename(full_path))

    serializer = ClothingItemCreateSerializer(data=request.data, context={"request": request})
    if serializer.is_valid():
        serializer.save(user=request.user)
        return Response({"message": "Saved successfully"}, status=201)
    
    print(serializer.errors) # Debugging
    return Response(serializer.errors, status=400)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def list_storage_units(request):
    """Return storage units for the logged-in user only, with parent info"""
    storages = StorageUnit.objects.filter(user=request.user).select_related('parent_storage')
    serializer = StorageUnitSerializer(storages, many=True)
    return Response(serializer.data)

def save_non_clothing_item(request):
    """
    Save a non-clothing item.
    Payload: { "storage_id": 1, "name": "Wallet", "description": "Leather" }
    """
    user = request.user
    storage_id = request.data.get("storage_id")
    name = request.data.get("name")
    description = request.data.get("description", "")

    if not storage_id or not name:
        return Response({"error": "storage_id and name are required"}, status=400)

    try:
        storage = StorageUnit.objects.get(id=storage_id, user=user)
    except StorageUnit.DoesNotExist:
        return Response({"error": "Storage unit not found or does not belong to user"}, status=404)

    item = NonClothingItem.objects.create(
        user=user,
        storage_unit=storage,
        name=name,
        description=description
    )

    serializer = NonClothingItemSerializer(item)
    return Response(serializer.data, status=201)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def list_non_clothing_items(request):
    """Return non-clothing items of the logged-in user"""
    items = NonClothingItem.objects.filter(user=request.user).select_related('storage_unit')
    serializer = NonClothingItemSerializer(items, many=True)
    return Response(serializer.data)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def authenticate_clothing(request):
    """
    Temporary stub: always returns True
    """
    return Response({"is_clothing": True}, status=200)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def extract_metadata(request):
    print(f"DEBUG: Incoming request data: {request.data}")
    segmented_url = request.data.get("segmented_image") or request.data.get("url")
    
    if not segmented_url:
        return Response({"error": "Key 'segmented_image' or 'url' is missing in request"}, status=400)

    try:
        media_url = settings.MEDIA_URL
        relative_path = segmented_url.split(media_url)[-1] if media_url in segmented_url else segmented_url
        image_path = Path(settings.MEDIA_ROOT) / relative_path

        if not image_path.exists():
            return Response({"error": f"Image not found at {image_path}"}, status=404)
        # color extraction logic
        colors = extract_colors_with_names(str(image_path))

        return Response({
            "dominant_color": colors.get("dominant_color", "Unknown"),
            "secondary_color": colors.get("secondary_color", "Unknown"),
            "category": "Topwear", 
            "subcategory": "Shirt",
            "occasion": "Casual",
        }, status=200)
    except Exception as e:
        print(f"DEBUG: Extraction Error: {e}")
        return Response({"error": str(e)}, status=500)
