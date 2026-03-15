from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

from .views.auth import *
from .views.admin import *
from .views.clothing import *
from .views.storage import *
from .views.non_clothing import *
from .views.outfit import *
from .views.accessory import *

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
    path('admin/users/', admin_users, name='admin_users'),
    path('admin/activity/', admin_activity, name='admin_activity'),
    path('admin/users/<int:user_id>/active/', admin_set_user_active, name='admin_set_user_active'),
    path('admin/users/<int:user_id>/staff/', admin_set_user_staff, name='admin_set_user_staff'),

    # Clothing item
    path('delete-segmented/', delete_segmented_image, name='delete_segmented_image'),
    path('non-clothing/', save_non_clothing_item, name='save_non_clothing_item'),
    path('non-clothing/list/', list_non_clothing_items, name='list_non_clothing_items'),
    path('non-clothing/<int:pk>/', non_clothing_detail, name='non_clothing_detail'),
    path("clothing/process/", clothing_process),
    path("clothing/save/", clothing_save),
    path("clothing/recent/", recent_clothes),
    path("clothing/all/", all_clothes),
    path("clothing/<int:pk>/toggle-favourite/", toggle_favourite),
    path("clothing/<int:pk>/", clothing_detail),
    path("clothing/<int:pk>/delete/", delete_clothing),
    path("clothing/<int:pk>/update/", update_clothing),
    path("accessories/process/", accessory_process),
    path("accessories/save/", accessory_save),
    path("accessories/all/", list_accessories),
    path("accessories/<int:pk>/", accessory_detail),
    path("accessories/<int:pk>/toggle-favourite/", toggle_accessory_favourite),

    #outfits
    path("outfits/", outfits),
    path("outfits/<int:pk>/", outfit_detail),
    path("outfits/<int:pk>/toggle-favourite/", toggle_outfit_favourite),
    
    #storage
    path("storage/<int:pk>/view/", storage_view),
    path('storage/', list_storage_units, name='list_storage_units'),
    path('storage/<int:pk>/', storage_detail, name='storage_detail'),
]
