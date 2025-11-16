from django.urls import path
from .views_test import TestModels

urlpatterns = [
    path("test-models/", TestModels.as_view()),
]
