from django.urls import path

from ..views.admin import AdminViewSet

admin_dashboard = AdminViewSet.as_view({"get": "dashboard"})
admin_users = AdminViewSet.as_view({"get": "users"})
admin_set_user_active = AdminViewSet.as_view({"post": "set_user_active"})
admin_set_user_staff = AdminViewSet.as_view({"post": "set_user_staff"})
admin_user_summary = AdminViewSet.as_view({"get": "user_summary"})
admin_user_clothing = AdminViewSet.as_view({"get": "user_clothing"})
admin_user_outfits = AdminViewSet.as_view({"get": "user_outfits"})
admin_send_password_reset = AdminViewSet.as_view({"post": "send_password_reset"})
admin_clothing_list = AdminViewSet.as_view({"get": "clothing_list"})
admin_clothing_detail = AdminViewSet.as_view({"get": "clothing_detail", "delete": "clothing_delete"})
admin_clothing_reclassify = AdminViewSet.as_view({"post": "clothing_reclassify"})
admin_outfits_list = AdminViewSet.as_view({"get": "outfits_list"})
admin_outfit_detail = AdminViewSet.as_view({"get": "outfit_detail", "delete": "outfit_delete"})
admin_non_clothing_list = AdminViewSet.as_view({"get": "non_clothing_list"})
admin_feedback_list = AdminViewSet.as_view({"get": "feedback_list"})
admin_feedback_mark_read = AdminViewSet.as_view({"post": "feedback_mark_read"})

urlpatterns = [
    path("dashboard/", admin_dashboard, name="admin_dashboard"),
    path("users/", admin_users, name="admin_users"),
    path("users/<int:user_id>/active/", admin_set_user_active, name="admin_set_user_active"),
    path("users/<int:user_id>/staff/", admin_set_user_staff, name="admin_set_user_staff"),
    path("users/<int:user_id>/", admin_user_summary, name="admin_user_summary"),
    path("users/<int:user_id>/clothing/", admin_user_clothing, name="admin_user_clothing"),
    path("users/<int:user_id>/outfits/", admin_user_outfits, name="admin_user_outfits"),
    path("users/<int:user_id>/password-reset/", admin_send_password_reset, name="admin_send_password_reset"),
    path("clothing/", admin_clothing_list, name="admin_clothing_list"),
    path("clothing/<int:item_id>/", admin_clothing_detail, name="admin_clothing_detail"),
    path("clothing/reclassify/", admin_clothing_reclassify, name="admin_clothing_reclassify"),
    path("outfits/", admin_outfits_list, name="admin_outfits_list"),
    path("outfits/<int:outfit_id>/", admin_outfit_detail, name="admin_outfit_detail"),
    path("non-clothing/", admin_non_clothing_list, name="admin_non_clothing_list"),
    path("feedback/", admin_feedback_list, name="admin_feedback_list"),
    path("feedback/<int:feedback_id>/read/", admin_feedback_mark_read, name="admin_feedback_mark_read"),
]
