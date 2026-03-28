from django.contrib.auth.models import User
from rest_framework import generics
from rest_framework.decorators import api_view, parser_classes, permission_classes
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken

from ..models import UserProfile
from ..serializer import RegisterSerializer


class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = RegisterSerializer


@api_view(["GET", "PUT"])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def profile(request):
    user = request.user
    profile_obj, _ = UserProfile.objects.get_or_create(user=user)

    if request.method == "GET":
        role = "admin" if user.is_staff else "user"
        return Response(
            {
                "username": user.username,
                "email": user.email,
                "first_name": user.first_name,
                "last_name": user.last_name,
                "role": role,
                "avatar": profile_obj.avatar.url if profile_obj.avatar else None,
            }
        )

    first_name = request.data.get("first_name")
    last_name = request.data.get("last_name")

    if first_name is not None:
        if not first_name:
            return Response({"error": "First name cannot be empty"})
        if len(first_name) > 30:
            return Response({"error": "First name is too long"})
        user.first_name = first_name

    if last_name is not None:
        if not last_name:
            return Response({"error": "Last name cannot be empty"})
        if len(last_name) > 30:
            return Response({"error": "Last name is too long"})
        user.last_name = last_name

    avatar = request.FILES.get("avatar")
    if avatar:
        profile_obj.avatar = avatar

    user.save()
    profile_obj.save()

    return Response(
        {
            "message": "Profile updated successfully",
            "first_name": user.first_name,
            "last_name": user.last_name,
            "avatar": profile_obj.avatar.url if profile_obj.avatar else None,
        },
        status=200,
    )


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def logout(request):
    try:
        refresh_token = request.data.get("refresh")
        token = RefreshToken(refresh_token)
        token.blacklist()
    except Exception:
        pass
    return Response({"detail": "Logged out"})
