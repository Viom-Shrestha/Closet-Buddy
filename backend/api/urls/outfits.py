from django.urls import path

from ..views.outfit import outfit_detail, outfits, toggle_outfit_favourite, mark_outfit_worn

urlpatterns = [
    path("", outfits),
    path("<int:pk>/", outfit_detail),
    path("<int:pk>/toggle-favourite/", toggle_outfit_favourite),
    path("<int:pk>/wear/", mark_outfit_worn),
]
