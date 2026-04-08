from datetime import timedelta

from django.contrib.auth.models import User, update_last_login
from drf_spectacular.utils import extend_schema, extend_schema_view
from rest_framework import generics
from rest_framework import status
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import viewsets
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.serializers import (
    TokenObtainPairSerializer,
    TokenObtainSerializer,
)
from rest_framework_simplejwt.settings import api_settings
from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken, OutstandingToken
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenObtainPairView

from ..models import UserProfile
from ..serializer import RegisterSerializer


class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = RegisterSerializer


class RememberMeRefreshToken(RefreshToken):
    lifetime = timedelta(days=365)


class RememberMeTokenObtainPairSerializer(TokenObtainPairSerializer):
    """Extend refresh token lifetime when remember_me is requested."""

    @staticmethod
    def _is_truthy(value):
        if isinstance(value, bool):
            return value
        if isinstance(value, (int, float)):
            return value != 0
        if isinstance(value, str):
            return value.strip().lower() in {"1", "true", "yes", "y", "on"}
        return False

    def validate(self, attrs):
        data = TokenObtainSerializer.validate(self, attrs)
        remember_me = self._is_truthy(self.initial_data.get("remember_me"))
        token_class = RememberMeRefreshToken if remember_me else self.token_class
        refresh = token_class.for_user(self.user)
        data["refresh"] = str(refresh)
        data["access"] = str(refresh.access_token)

        if api_settings.UPDATE_LAST_LOGIN:
            update_last_login(None, self.user)

        return data


class RememberMeTokenObtainPairView(TokenObtainPairView):
    serializer_class = RememberMeTokenObtainPairSerializer


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

def logout(request):
    refresh_token = request.data.get("refresh")
    if refresh_token:
        try:
            token = RefreshToken(refresh_token)
            token.blacklist()
        except TokenError:
            return Response({"detail": "Invalid refresh token."}, status=status.HTTP_400_BAD_REQUEST)

        return Response({"detail": "Logged out"}, status=status.HTTP_200_OK)

    # Swagger users often authorize with only an access token and do not send
    # refresh in the request body. In that case, revoke all outstanding
    # refresh tokens for this authenticated user.
    for outstanding_token in OutstandingToken.objects.filter(user=request.user):
        BlacklistedToken.objects.get_or_create(token=outstanding_token)

    return Response({"detail": "Logged out"}, status=status.HTTP_200_OK)


@extend_schema_view(
    profile=extend_schema(summary="Get/update profile"),
    logout=extend_schema(summary="Logout"),
)
class AuthViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def profile(self, request):
        return profile(request)

    def logout(self, request):
        return logout(request)
