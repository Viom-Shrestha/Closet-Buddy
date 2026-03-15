from django.urls import path

from ..views.outfit import outfit_detail, outfits, toggle_outfit_favourite

urlpatterns = [
    path("", outfits),
    path("<int:pk>/", outfit_detail),
    path("<int:pk>/toggle-favourite/", toggle_outfit_favourite),
]
