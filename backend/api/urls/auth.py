from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView

from ..views.auth import RegisterView, RememberMeTokenObtainPairView, logout

urlpatterns = [
    path("register/", RegisterView.as_view(), name="register"),
    path("login/", RememberMeTokenObtainPairView.as_view(), name="login"),
    path("refresh/", TokenRefreshView.as_view(), name="token_refresh"),
    path("logout/", logout, name="logout"),
]
