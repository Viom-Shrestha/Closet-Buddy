from django.urls import path

from ..views.clothing import (
    all_clothes,
    clothing_detail,
    clothing_process,
    clothing_save,
    delete_clothing,
    delete_segmented_image,
    recent_clothes,
    toggle_favourite,
    update_clothing,
)

urlpatterns = [
    path("process/", clothing_process),
    path("save/", clothing_save),
    path("recent/", recent_clothes),
    path("all/", all_clothes),
    path("segmented/delete/", delete_segmented_image, name="delete_segmented_image"),
    path("<int:pk>/toggle-favourite/", toggle_favourite),
    path("<int:pk>/", clothing_detail),
    path("<int:pk>/delete/", delete_clothing),
    path("<int:pk>/update/", update_clothing),
]
