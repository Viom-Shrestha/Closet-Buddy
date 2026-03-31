from django.urls import path

from ..views.outfit import (
    mark_outfit_worn,
    outfit_detail,
    outfits,
    rate_outfit_ai,
    toggle_outfit_favourite,
)

urlpatterns = [
    path("", outfits),
    path("ai-rate/", rate_outfit_ai),
    path("<int:pk>/", outfit_detail),
    path("<int:pk>/toggle-favourite/", toggle_outfit_favourite),
    path("<int:pk>/wear/", mark_outfit_worn),
]
