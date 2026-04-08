from django.urls import path

from ..views.storage import StorageUnitViewSet

storage_list = StorageUnitViewSet.as_view({"get": "list", "post": "create"})
storage_detail = StorageUnitViewSet.as_view({"put": "update", "delete": "destroy"})
storage_view = StorageUnitViewSet.as_view({"get": "view"})

urlpatterns = [
    path("", storage_list, name="list_storage_units"),
    path("<int:pk>/", storage_detail, name="storage_detail"),
    path("<int:pk>/view/", storage_view, name="storage_view"),
]
