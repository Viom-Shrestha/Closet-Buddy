from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

from .views.auth import *
from .views.admin import *
from .views.clothing import *
from .views.storage import *
from .views.non_clothing import *
from .views.outfit import *

urlpatterns = [
    # Auth
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', TokenObtainPairView.as_view(), name='login'),
    path('refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('logout/', logout, name='logout'),

    # Profile
    path('profile/', profile, name='profile'),
    path('profile/update/', profile, name='profile-update'),

    # Admin
    path('admin-dashboard/', admin_dashboard, name='admin_dashboard'),

    # Clothing item
    path('delete-segmented/', delete_segmented_image, name='delete_segmented_image'),
    path('non-clothing/', save_non_clothing_item, name='save_non_clothing_item'),
    path('non-clothing/list/', list_non_clothing_items, name='list_non_clothing_items'),
    path("clothing/process/", clothing_process),
    path("clothing/save/", clothing_save),
    path("clothing/recent/", recent_clothes),
    path("clothing/<int:pk>/toggle-favourite/", toggle_favourite),
    path("clothing/<int:pk>/", clothing_detail),
    path("clothing/<int:pk>/delete/", delete_clothing),
    path("clothing/<int:pk>/update/", update_clothing),

    #outfits
    path("outfits/", outfits),
    
    #storage
    path("storage/<int:pk>/view/", storage_view),
    path('storage/', list_storage_units, name='list_storage_units'),
    path('storage/<int:pk>/', storage_detail, name='storage_detail'),
]
