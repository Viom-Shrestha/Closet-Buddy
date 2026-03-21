from django.urls import path

from ..views.recommendation import recommend_outfits_view


urlpatterns = [
    path("", recommend_outfits_view),
]
