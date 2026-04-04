from django.urls import path

from ..views.recommendation import occasion_catalog_view


urlpatterns = [
    path("", occasion_catalog_view, name="occasion_catalog"),
]
