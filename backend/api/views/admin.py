from datetime import timedelta

from django.contrib.auth.models import User
from django.db.models import Count, Q
from django.utils import timezone
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from ..models import AccessoryItem, ClothingItem, NonClothingItem, Outfit, StorageUnit


def _as_bool(value):
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.lower() in ["true", "1", "yes", "on"]
    return bool(value)


def _require_admin(request):
    if request.user.is_staff:
        return None
    return Response({"detail": "Admin access required"}, status=403)


def _serialize_user_row(user):
    return {
        "id": user.id,
        "username": user.username,
        "email": user.email,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "is_staff": user.is_staff,
        "is_active": user.is_active,
        "date_joined": user.date_joined,
        "clothing_count": getattr(user, "clothing_count", 0),
        "outfit_count": getattr(user, "outfit_count", 0),
        "storage_count": getattr(user, "storage_count", 0),
        "accessory_count": getattr(user, "accessory_count", 0),
    }


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def admin_dashboard(request):
    denied = _require_admin(request)
    if denied:
        return denied

    since = timezone.now() - timedelta(days=7)

    top_categories = list(
        ClothingItem.objects.values("category")
        .annotate(total=Count("id"))
        .order_by("-total")[:6]
    )
    top_colors = list(
        ClothingItem.objects.values("dominant_color")
        .annotate(total=Count("id"))
        .order_by("-total")[:6]
    )
    storage_types = list(
        StorageUnit.objects.values("type").annotate(total=Count("id")).order_by("-total")
    )

    recent_users_qs = (
        User.objects.order_by("-date_joined")
        .annotate(
            clothing_count=Count("clothing_items", distinct=True),
            outfit_count=Count("outfits", distinct=True),
            storage_count=Count("storage_units", distinct=True),
            accessory_count=Count("accessory_items", distinct=True),
        )[:8]
    )

    recent_users = []
    for user in recent_users_qs:
        row = _serialize_user_row(user)
        row["date_joined"] = user.date_joined.isoformat()
        recent_users.append(row)

    return Response(
        {
            "overview": {
                "total_users": User.objects.count(),
                "active_users": User.objects.filter(is_active=True).count(),
                "admin_users": User.objects.filter(is_staff=True).count(),
                "total_storages": StorageUnit.objects.count(),
                "total_clothing_items": ClothingItem.objects.count(),
                "total_accessories": AccessoryItem.objects.count(),
                "total_non_clothing": NonClothingItem.objects.count(),
                "total_outfits": Outfit.objects.count(),
            },
            "last_7_days": {
                "new_users": User.objects.filter(date_joined__gte=since).count(),
                "new_storages": StorageUnit.objects.filter(created_at__gte=since).count(),
                "new_clothing": ClothingItem.objects.filter(created_at__gte=since).count(),
                "new_accessories": AccessoryItem.objects.filter(created_at__gte=since).count(),
                "new_non_clothing": NonClothingItem.objects.filter(created_at__gte=since).count(),
                "new_outfits": Outfit.objects.filter(created_at__gte=since).count(),
            },
            "top_categories": top_categories,
            "top_colors": top_colors,
            "storage_types": storage_types,
            "recent_users": recent_users,
        }
    )


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def admin_users(request):
    denied = _require_admin(request)
    if denied:
        return denied

    query = (request.GET.get("q") or "").strip()
    limit_raw = request.GET.get("limit") or "100"
    try:
        limit = max(1, min(int(limit_raw), 200))
    except ValueError:
        limit = 100

    users = User.objects.all()
    if query:
        users = users.filter(
            Q(username__icontains=query)
            | Q(email__icontains=query)
            | Q(first_name__icontains=query)
            | Q(last_name__icontains=query)
        )

    users = users.order_by("-date_joined").annotate(
        clothing_count=Count("clothing_items", distinct=True),
        outfit_count=Count("outfits", distinct=True),
        storage_count=Count("storage_units", distinct=True),
        accessory_count=Count("accessory_items", distinct=True),
    )[:limit]

    results = []
    for user in users:
        row = _serialize_user_row(user)
        row["date_joined"] = user.date_joined.isoformat()
        row["can_edit"] = user.id != request.user.id
        results.append(row)

    return Response({"results": results, "query": query, "limit": limit})


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def admin_activity(request):
    denied = _require_admin(request)
    if denied:
        return denied

    limit_raw = request.GET.get("limit") or "60"
    try:
        limit = max(10, min(int(limit_raw), 200))
    except ValueError:
        limit = 60

    activity = []

    for user in User.objects.order_by("-date_joined")[:limit]:
        activity.append(
            {
                "type": "user_signup",
                "title": f"New user joined: {user.username}",
                "subtitle": user.email,
                "username": user.username,
                "created_at": user.date_joined,
            }
        )

    for item in ClothingItem.objects.select_related("user").order_by("-created_at")[:limit]:
        activity.append(
            {
                "type": "clothing_upload",
                "title": f"Clothing uploaded: {item.subcategory}",
                "subtitle": f"{item.category} • {item.dominant_color}",
                "username": item.user.username,
                "created_at": item.created_at,
            }
        )

    for item in AccessoryItem.objects.select_related("user").order_by("-created_at")[:limit]:
        activity.append(
            {
                "type": "accessory_upload",
                "title": f"Accessory uploaded: {item.name}",
                "subtitle": item.dominant_color,
                "username": item.user.username,
                "created_at": item.created_at,
            }
        )

    for outfit in Outfit.objects.select_related("user").order_by("-created_at")[:limit]:
        activity.append(
            {
                "type": "outfit_saved",
                "title": f"Outfit saved: {outfit.name}",
                "subtitle": outfit.occasion or "No occasion",
                "username": outfit.user.username,
                "created_at": outfit.created_at,
            }
        )

    for storage in StorageUnit.objects.select_related("user").order_by("-created_at")[:limit]:
        activity.append(
            {
                "type": "storage_created",
                "title": f"Storage created: {storage.name}",
                "subtitle": storage.type,
                "username": storage.user.username,
                "created_at": storage.created_at,
            }
        )

    activity.sort(key=lambda item: item["created_at"], reverse=True)
    trimmed = activity[:limit]

    for item in trimmed:
        item["created_at"] = item["created_at"].isoformat()

    return Response({"results": trimmed, "limit": limit})


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def admin_set_user_active(request, user_id):
    denied = _require_admin(request)
    if denied:
        return denied

    if request.user.id == user_id:
        return Response({"detail": "You cannot change your own active status."}, status=400)

    try:
        target = User.objects.get(id=user_id)
    except User.DoesNotExist:
        return Response({"detail": "User not found."}, status=404)

    target.is_active = _as_bool(request.data.get("is_active"))
    target.save(update_fields=["is_active"])

    return Response({"id": target.id, "is_active": target.is_active})


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def admin_set_user_staff(request, user_id):
    denied = _require_admin(request)
    if denied:
        return denied

    if request.user.id == user_id:
        return Response({"detail": "You cannot change your own admin role."}, status=400)

    try:
        target = User.objects.get(id=user_id)
    except User.DoesNotExist:
        return Response({"detail": "User not found."}, status=404)

    target.is_staff = _as_bool(request.data.get("is_staff"))
    target.save(update_fields=["is_staff"])

    return Response({"id": target.id, "is_staff": target.is_staff})
