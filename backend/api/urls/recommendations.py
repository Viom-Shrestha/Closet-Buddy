from django.urls import path

from ..views.recommendation import RecommendationViewSet

recommend_outfits = RecommendationViewSet.as_view({"post": "recommend"})

urlpatterns = [
    path("", recommend_outfits),
]
