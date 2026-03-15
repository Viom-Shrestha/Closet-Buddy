from django.urls import path

from ..views.non_clothing import (
    list_non_clothing_items,
    non_clothing_detail,
    save_non_clothing_item,
)

urlpatterns = [
    path("", save_non_clothing_item, name="save_non_clothing_item"),
    path("list/", list_non_clothing_items, name="list_non_clothing_items"),
    path("<int:pk>/", non_clothing_detail, name="non_clothing_detail"),
]
