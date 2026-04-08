from django.urls import path

from ..views.recommendation import RecommendationViewSet

occasion_catalog = RecommendationViewSet.as_view({"get": "occasions"})

urlpatterns = [
    path("", occasion_catalog, name="occasion_catalog"),
]
