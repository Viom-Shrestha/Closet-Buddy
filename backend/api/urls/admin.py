from django.urls import path

from ..views.admin import (
    admin_activity,
    admin_dashboard,
    admin_set_user_active,
    admin_set_user_staff,
    admin_users,
)

urlpatterns = [
    path("dashboard/", admin_dashboard, name="admin_dashboard"),
    path("users/", admin_users, name="admin_users"),
    path("activity/", admin_activity, name="admin_activity"),
    path("users/<int:user_id>/active/", admin_set_user_active, name="admin_set_user_active"),
    path("users/<int:user_id>/staff/", admin_set_user_staff, name="admin_set_user_staff"),
]
