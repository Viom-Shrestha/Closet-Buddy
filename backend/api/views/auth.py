from django.contrib.auth.models import User
from rest_framework import generics
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken

from ..serializer import RegisterSerializer

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