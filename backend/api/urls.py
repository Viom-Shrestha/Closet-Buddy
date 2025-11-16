from django.urls import path
from .views import UploadClothingItem

urlpatterns = [
    path("upload-item/", UploadClothingItem.as_view()),
]
