from django.urls import path

from ..views.accessory import AccessoryViewSet

accessory_process = AccessoryViewSet.as_view({"post": "process"})
accessory_save = AccessoryViewSet.as_view({"post": "save"})
accessory_all = AccessoryViewSet.as_view({"get": "all"})
accessory_detail = AccessoryViewSet.as_view({"get": "retrieve", "put": "update", "delete": "destroy"})
accessory_toggle_favourite = AccessoryViewSet.as_view({"post": "toggle_favourite"})

urlpatterns = [
    path("process/", accessory_process),
    path("save/", accessory_save),
    path("all/", accessory_all),
    path("<int:pk>/", accessory_detail),
    path("<int:pk>/toggle-favourite/", accessory_toggle_favourite),
]
