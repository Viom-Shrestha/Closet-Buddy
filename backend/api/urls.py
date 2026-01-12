from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

from .views import (
    RegisterView, profile, admin_dashboard, 
    segment_clothing, save_clothing_item,
    delete_segmented_image, logout,list_storage_units,
    save_non_clothing_item, list_non_clothing_items, extract_metadata, authenticate_clothing
)

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
    path('segment/', segment_clothing, name='segment_clothing'),
    path('save-clothing/', save_clothing_item, name='save_clothing_item'),
    path('delete-segmented/', delete_segmented_image, name='delete_segmented_image'),
    path('storage/', list_storage_units, name='list_storage_units'),
    path('non-clothing/', save_non_clothing_item, name='save_non_clothing_item'),
    path('non-clothing/list/', list_non_clothing_items, name='list_non_clothing_items'),
    path('ai/authenticate-clothing/', authenticate_clothing, name='authenticate_clothing'),
    path('ai/extract-metadata/', extract_metadata, name='extract_metadata'),

]
