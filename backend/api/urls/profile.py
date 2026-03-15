from django.urls import path

from ..views.auth import profile

urlpatterns = [
    path("", profile, name="profile"),
]
