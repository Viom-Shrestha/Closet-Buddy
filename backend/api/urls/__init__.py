from django.urls import include, path

urlpatterns = [
    path("auth/", include("api.urls.auth")),
    path("profile/", include("api.urls.profile")),
    path("admin/", include("api.urls.admin")),
    path("clothing/", include("api.urls.clothing")),
    path("accessories/", include("api.urls.accessories")),
    path("outfits/", include("api.urls.outfits")),
    path("recommendations/", include("api.urls.recommendations")),
    path("occasions/", include("api.urls.occasions")),
    path("storage/", include("api.urls.storage")),
    path("non-clothing/", include("api.urls.non_clothing")),
    path("feedback/", include("api.urls.feedback")),
]
