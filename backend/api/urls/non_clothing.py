from django.urls import path

from ..views.non_clothing import NonClothingViewSet

non_clothing_create = NonClothingViewSet.as_view({"post": "create"})
non_clothing_list = NonClothingViewSet.as_view({"get": "list"})
non_clothing_detail = NonClothingViewSet.as_view({"get": "retrieve", "put": "update", "delete": "destroy"})

urlpatterns = [
    path("", non_clothing_create, name="save_non_clothing_item"),
    path("list/", non_clothing_list, name="list_non_clothing_items"),
    path("<int:pk>/", non_clothing_detail, name="non_clothing_detail"),
]
