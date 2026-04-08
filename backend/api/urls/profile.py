from django.urls import path

from ..views.auth import AuthViewSet

profile = AuthViewSet.as_view({"get": "profile", "put": "profile"})

urlpatterns = [
    path("", profile, name="profile"),
]
