from django.urls import path

from ..views.clothing import ClothingViewSet

clothing_process = ClothingViewSet.as_view({"post": "process"})
clothing_save = ClothingViewSet.as_view({"post": "save"})
clothing_recent = ClothingViewSet.as_view({"get": "recent"})
clothing_all = ClothingViewSet.as_view({"get": "all"})
clothing_delete_segmented = ClothingViewSet.as_view({"post": "delete_segmented"})
clothing_toggle_favourite = ClothingViewSet.as_view({"post": "toggle_favourite"})
clothing_detail = ClothingViewSet.as_view({"get": "retrieve"})
clothing_delete = ClothingViewSet.as_view({"delete": "delete_item"})
clothing_update = ClothingViewSet.as_view({"put": "update_item"})

urlpatterns = [
    path("process/", clothing_process),
    path("save/", clothing_save),
    path("recent/", clothing_recent),
    path("all/", clothing_all),
    path("segmented/delete/", clothing_delete_segmented, name="delete_segmented_image"),
    path("<int:pk>/toggle-favourite/", clothing_toggle_favourite),
    path("<int:pk>/", clothing_detail),
    path("<int:pk>/delete/", clothing_delete),
    path("<int:pk>/update/", clothing_update),
]
