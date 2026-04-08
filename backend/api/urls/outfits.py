from django.urls import path

from ..views.outfit import OutfitViewSet

outfit_list = OutfitViewSet.as_view({"get": "list", "post": "create"})
outfit_detail = OutfitViewSet.as_view(
    {"get": "retrieve", "put": "update", "patch": "partial_update", "delete": "destroy"}
)
outfit_ai_rate = OutfitViewSet.as_view({"post": "ai_rate"})
outfit_toggle_favourite = OutfitViewSet.as_view({"post": "toggle_favourite"})
outfit_wear = OutfitViewSet.as_view({"post": "wear"})

urlpatterns = [
    path("", outfit_list),
    path("ai-rate/", outfit_ai_rate),
    path("<int:pk>/", outfit_detail),
    path("<int:pk>/toggle-favourite/", outfit_toggle_favourite),
    path("<int:pk>/wear/", outfit_wear),
]
