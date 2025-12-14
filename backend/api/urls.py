from django.urls import path
from .views import RegisterView,profile,admin_dashboard,segment_clothing, delete_segmented_image
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

urlpatterns = [
    path('register/', RegisterView.as_view()),
    path('login/', TokenObtainPairView.as_view()),
    path('profile/', profile),
    path('refresh/', TokenRefreshView.as_view()),
    path('admin-dashboard/', admin_dashboard),
    path('segment/', segment_clothing),
    path('delete-segmented/', delete_segmented_image), 
]

