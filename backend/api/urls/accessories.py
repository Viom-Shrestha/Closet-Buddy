from django.urls import path

from ..views.accessory import (
    accessory_detail,
    accessory_process,
    accessory_save,
    list_accessories,
    toggle_accessory_favourite,
)

urlpatterns = [
    path("process/", accessory_process),
    path("save/", accessory_save),
    path("all/", list_accessories),
    path("<int:pk>/", accessory_detail),
    path("<int:pk>/toggle-favourite/", toggle_accessory_favourite),
]
