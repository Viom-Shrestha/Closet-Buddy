from django.urls import path

from ..views.storage import list_storage_units, storage_detail, storage_view

urlpatterns = [
    path("", list_storage_units, name="list_storage_units"),
    path("<int:pk>/", storage_detail, name="storage_detail"),
    path("<int:pk>/view/", storage_view),
]
