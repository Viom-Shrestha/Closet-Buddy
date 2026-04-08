from datetime import timedelta

from django.conf import settings
from django.contrib.auth.models import User
from django.contrib.auth.forms import PasswordResetForm
from django.db.models import Avg, Count, Q
from django.utils import timezone
from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from ..models import (
    AccessoryItem,
    BetaFeedback,
    ClothingItem,
    NonClothingItem,
    Outfit,
    StorageUnit,
    UserProfile,
)
from ..serializer import (
    ClothingItemSerializer,
    NonClothingItemSerializer,
    OutfitReadSerializer,
)


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
        "last_active_at": user.last_login,
        "clothing_count": getattr(user, "clothing_count", 0),
        "outfit_count": getattr(user, "outfit_count", 0),
        "storage_count": getattr(user, "storage_count", 0),
        "accessory_count": getattr(user, "accessory_count", 0),
    }


def _parse_limit_offset(request, default_limit=50, max_limit=200):
    limit_raw = request.GET.get("limit") or str(default_limit)
    offset_raw = request.GET.get("offset") or "0"
    try:
        limit = max(1, min(int(limit_raw), max_limit))
    except ValueError:
        limit = default_limit
    try:
        offset = max(0, int(offset_raw))
    except ValueError:
        offset = 0
    return limit, offset


def _slot_text(category: str, subcategory: str) -> str:
    return f"{category} {subcategory}".lower()


def _is_shoe_label(category: str, subcategory: str) -> bool:
    text = _slot_text(category, subcategory)
    keys = ["shoe", "sneaker", "boot", "heel", "footwear", "slipper", "sandal", "loafer"]
    return any(key in text for key in keys)


def _is_bottom_label(category: str, subcategory: str) -> bool:
    text = _slot_text(category, subcategory)
    keys = ["pant", "trouser", "jean", "short", "skirt", "bottom", "jogger", "legging", "cargo"]
    return any(key in text for key in keys)


def _is_outerwear_label(category: str, subcategory: str) -> bool:
    text = _slot_text(category, subcategory)
    keys = ["jacket", "coat", "blazer", "cardigan", "hoodie", "outerwear", "parka", "trench"]
    return any(key in text for key in keys)


def _to_non_negative_int(value) -> int:
    try:
        return max(0, int(value))
    except (TypeError, ValueError):
        return 0


def _engagement_from_profiles(today, week_start):
    today_key = today.isoformat()
    week_keys = {
        (week_start + timedelta(days=i)).isoformat()
        for i in range(7)
    }
    dau = 0
    wau = 0
    total_sessions = 0
    total_seconds = 0

    for profile in UserProfile.objects.only("activity_daily").iterator():
        activity_daily = profile.activity_daily or {}
        if not isinstance(activity_daily, dict):
            continue

        today_entry = activity_daily.get(today_key)
        if isinstance(today_entry, dict):
            today_sessions = _to_non_negative_int(today_entry.get("session_count"))
            today_seconds = _to_non_negative_int(today_entry.get("total_session_seconds"))
            if today_sessions > 0 or today_seconds > 0:
                dau += 1

        is_weekly_active = False
        for key in week_keys:
            entry = activity_daily.get(key)
            if not isinstance(entry, dict):
                continue
            sessions = _to_non_negative_int(entry.get("session_count"))
            seconds = _to_non_negative_int(entry.get("total_session_seconds"))
            total_sessions += sessions
            total_seconds += seconds
            if sessions > 0 or seconds > 0:
                is_weekly_active = True

        if is_weekly_active:
            wau += 1

    return dau, wau, total_sessions, total_seconds


def admin_dashboard(request):
    denied = _require_admin(request)
    if denied:
        return denied

    now = timezone.now()
    since = now - timedelta(days=7)
    today = now.date()
    week_start = today - timedelta(days=6)

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
        row["last_active_at"] = user.last_login.isoformat() if user.last_login else None
        recent_users.append(row)

    total_users = User.objects.count()
    total_clothing = ClothingItem.objects.count()
    total_outfits = Outfit.objects.count()
    favourite_outfits = Outfit.objects.filter(is_favourite=True).count()

    dau, wau, total_sessions, total_seconds = _engagement_from_profiles(
        today=today,
        week_start=week_start,
    )
    average_session_seconds = int(total_seconds / total_sessions) if total_sessions else 0
    sessions_per_user = round(total_sessions / wau, 2) if wau else 0

    avg_rating = Outfit.objects.filter(rating__isnull=False).aggregate(avg=Avg("rating"))["avg"]
    favourite_rate = round((favourite_outfits / total_outfits) * 100, 2) if total_outfits else 0.0
    avg_wardrobe = round(total_clothing / total_users, 2) if total_users else 0.0

    top_outfit_items = list(
        ClothingItem.objects.filter(outfits__isnull=False)
        .values("id", "category", "subcategory")
        .annotate(total=Count("outfits"))
        .order_by("-total")[:6]
    )

    def slot_user_count(keys):
        query = Q()
        for key in keys:
            query |= Q(category__icontains=key) | Q(subcategory__icontains=key)
        return ClothingItem.objects.filter(query).values("user_id").distinct().count()

    topwear_users = slot_user_count(["top", "shirt", "tee", "blouse", "sweater", "tank", "polo"])
    bottom_users = slot_user_count(["pant", "trouser", "jean", "short", "skirt", "bottom", "jogger", "legging", "cargo"])
    shoe_users = slot_user_count(["shoe", "sneaker", "boot", "heel", "footwear", "slipper", "sandal", "loafer"])
    outerwear_users = slot_user_count(["jacket", "coat", "blazer", "cardigan", "hoodie", "outerwear", "parka", "trench"])
    accessory_users = AccessoryItem.objects.values("user_id").distinct().count()

    def percent(count):
        return round((count / total_users) * 100, 2) if total_users else 0.0

    outfits_per_day = []
    for i in range(7):
        day = today - timedelta(days=i)
        outfits_per_day.append(
            {
                "date": day.isoformat(),
                "count": Outfit.objects.filter(created_at__date=day).count(),
            }
        )
    outfits_per_day.reverse()

    return Response(
        {
            "overview": {
                "total_users": total_users,
                "active_users": User.objects.filter(is_active=True).count(),
                "admin_users": User.objects.filter(is_staff=True).count(),
                "total_storages": StorageUnit.objects.count(),
                "total_clothing_items": total_clothing,
                "total_accessories": AccessoryItem.objects.count(),
                "total_non_clothing": NonClothingItem.objects.count(),
                "total_outfits": total_outfits,
            },
            "last_7_days": {
                "new_users": User.objects.filter(date_joined__gte=since).count(),
                "new_storages": StorageUnit.objects.filter(created_at__gte=since).count(),
                "new_clothing": ClothingItem.objects.filter(created_at__gte=since).count(),
                "new_accessories": AccessoryItem.objects.filter(created_at__gte=since).count(),
                "new_non_clothing": NonClothingItem.objects.filter(created_at__gte=since).count(),
                "new_outfits": Outfit.objects.filter(created_at__gte=since).count(),
            },
            "engagement": {
                "dau": dau,
                "wau": wau,
                "sessions_per_user": sessions_per_user,
                "average_session_seconds": average_session_seconds,
            },
            "wardrobe_stats": {
                "average_wardrobe_size": avg_wardrobe,
            },
            "outfit_stats": {
                "average_rating": round(avg_rating, 2) if avg_rating is not None else None,
                "favourite_rate": favourite_rate,
                "outfits_per_day": outfits_per_day,
                "most_used_items": top_outfit_items,
            },
            "slot_coverage": {
                "topwear_percent": percent(topwear_users),
                "bottomwear_percent": percent(bottom_users),
                "shoes_percent": percent(shoe_users),
                "outerwear_percent": percent(outerwear_users),
                "accessories_percent": percent(accessory_users),
            },
            "top_categories": top_categories,
            "top_colors": top_colors,
            "storage_types": storage_types,
            "recent_users": recent_users,
        }
    )


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
        row["last_active_at"] = user.last_login.isoformat() if user.last_login else None
        row["can_edit"] = user.id != request.user.id
        results.append(row)

    return Response({"results": results, "query": query, "limit": limit})



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


def admin_user_summary(request, user_id):
    denied = _require_admin(request)
    if denied:
        return denied

    try:
        user = User.objects.get(id=user_id)
    except User.DoesNotExist:
        return Response({"detail": "User not found."}, status=404)

    clothing = ClothingItem.objects.filter(user=user)
    accessories = AccessoryItem.objects.filter(user=user)
    outfits = Outfit.objects.filter(user=user)

    category_counts = list(
        clothing.values("category")
        .annotate(total=Count("id"))
        .order_by("-total")
    )

    return Response(
        {
            "user": {
                "id": user.id,
                "username": user.username,
                "email": user.email,
                "first_name": user.first_name,
                "last_name": user.last_name,
                "date_joined": user.date_joined.isoformat(),
                "last_active_at": user.last_login.isoformat() if user.last_login else None,
                "is_active": user.is_active,
                "is_staff": user.is_staff,
            },
            "counts": {
                "clothing": clothing.count(),
                "accessories": accessories.count(),
                "outfits": outfits.count(),
            },
            "category_counts": category_counts,
        }
    )


def admin_user_clothing(request, user_id):
    denied = _require_admin(request)
    if denied:
        return denied

    try:
        user = User.objects.get(id=user_id)
    except User.DoesNotExist:
        return Response({"detail": "User not found."}, status=404)

    limit, offset = _parse_limit_offset(request)
    qs = ClothingItem.objects.filter(user=user).order_by("-created_at")
    total = qs.count()
    items = qs[offset : offset + limit]
    serializer = ClothingItemSerializer(items, many=True, context={"request": request})
    return Response({"results": serializer.data, "total": total, "limit": limit, "offset": offset})


def admin_user_outfits(request, user_id):
    denied = _require_admin(request)
    if denied:
        return denied

    try:
        user = User.objects.get(id=user_id)
    except User.DoesNotExist:
        return Response({"detail": "User not found."}, status=404)

    limit, offset = _parse_limit_offset(request)
    qs = Outfit.objects.filter(user=user).order_by("-created_at")
    total = qs.count()
    items = qs[offset : offset + limit]
    serializer = OutfitReadSerializer(items, many=True, context={"request": request})
    return Response({"results": serializer.data, "total": total, "limit": limit, "offset": offset})


def admin_send_password_reset(request, user_id):
    denied = _require_admin(request)
    if denied:
        return denied

    try:
        user = User.objects.get(id=user_id)
    except User.DoesNotExist:
        return Response({"detail": "User not found."}, status=404)

    form = PasswordResetForm({"email": user.email})
    if not form.is_valid():
        return Response({"detail": "Invalid email for password reset."}, status=400)

    form.save(
        request=request,
        use_https=request.is_secure(),
        from_email=getattr(settings, "DEFAULT_FROM_EMAIL", None),
        email_template_name="registration/password_reset_email.html",
        subject_template_name="registration/password_reset_subject.txt",
    )
    return Response({"detail": "Password reset email sent."})


def admin_clothing_list(request):
    denied = _require_admin(request)
    if denied:
        return denied

    limit, offset = _parse_limit_offset(request, default_limit=40)
    qs = ClothingItem.objects.select_related("user", "storage_unit").order_by("-created_at")

    user_id = request.GET.get("user_id")
    if user_id:
        qs = qs.filter(user_id=user_id)

    category = (request.GET.get("category") or "").strip()
    if category:
        qs = qs.filter(category__icontains=category)

    subcategory = (request.GET.get("subcategory") or "").strip()
    if subcategory:
        qs = qs.filter(subcategory__icontains=subcategory)

    color = (request.GET.get("dominant_color") or "").strip()
    if color:
        qs = qs.filter(dominant_color__icontains=color)

    query = (request.GET.get("q") or "").strip()
    if query:
        qs = qs.filter(
            Q(category__icontains=query)
            | Q(subcategory__icontains=query)
            | Q(user__username__icontains=query)
            | Q(user__email__icontains=query)
        )

    total = qs.count()
    items = qs[offset : offset + limit]
    data = []
    for item in items:
        payload = ClothingItemSerializer(item, context={"request": request}).data
        payload["user"] = {
            "id": item.user_id,
            "username": item.user.username,
            "email": item.user.email,
        }
        data.append(payload)

    return Response({"results": data, "total": total, "limit": limit, "offset": offset})


def admin_clothing_detail(request, item_id):
    denied = _require_admin(request)
    if denied:
        return denied

    try:
        item = ClothingItem.objects.select_related("user", "storage_unit").get(id=item_id)
    except ClothingItem.DoesNotExist:
        return Response({"detail": "Item not found."}, status=404)

    if request.method == "DELETE":
        item.image.delete(save=False)
        item.delete()
        return Response(status=204)

    payload = ClothingItemSerializer(item, context={"request": request}).data
    payload["user"] = {
        "id": item.user_id,
        "username": item.user.username,
        "email": item.user.email,
    }
    return Response(payload)


def admin_clothing_reclassify(request):
    denied = _require_admin(request)
    if denied:
        return denied

    ids = request.data.get("ids") or []
    if not isinstance(ids, list) or not ids:
        return Response({"detail": "ids must be a non-empty list."}, status=400)

    category = (request.data.get("category") or "").strip()
    subcategory = (request.data.get("subcategory") or "").strip()

    if not category and not subcategory:
        return Response({"detail": "category or subcategory required."}, status=400)

    updates = {}
    if category:
        updates["category"] = category
    if subcategory:
        updates["subcategory"] = subcategory

    updated = ClothingItem.objects.filter(id__in=ids).update(**updates)
    return Response({"updated": updated})


def admin_outfits_list(request):
    denied = _require_admin(request)
    if denied:
        return denied

    limit, offset = _parse_limit_offset(request, default_limit=40)
    qs = Outfit.objects.select_related("user").order_by("-created_at")

    user_id = request.GET.get("user_id")
    if user_id:
        qs = qs.filter(user_id=user_id)

    occasion = (request.GET.get("occasion") or "").strip()
    if occasion:
        qs = qs.filter(occasion__icontains=occasion)

    favourite = request.GET.get("is_favourite")
    if favourite is not None:
        qs = qs.filter(is_favourite=_as_bool(favourite))

    rating = request.GET.get("rating")
    if rating:
        try:
            qs = qs.filter(rating=int(rating))
        except ValueError:
            pass

    total = qs.count()
    items = qs[offset : offset + limit]
    data = []
    for outfit in items:
        payload = OutfitReadSerializer(outfit, context={"request": request}).data
        payload["user"] = {
            "id": outfit.user_id,
            "username": outfit.user.username,
            "email": outfit.user.email,
        }
        data.append(payload)

    return Response({"results": data, "total": total, "limit": limit, "offset": offset})


def admin_outfit_detail(request, outfit_id):
    denied = _require_admin(request)
    if denied:
        return denied

    try:
        outfit = Outfit.objects.select_related("user").get(id=outfit_id)
    except Outfit.DoesNotExist:
        return Response({"detail": "Outfit not found."}, status=404)

    payload = OutfitReadSerializer(outfit, context={"request": request}).data
    payload["user"] = {
        "id": outfit.user_id,
        "username": outfit.user.username,
        "email": outfit.user.email,
    }
    return Response(payload)


def admin_non_clothing_list(request):
    denied = _require_admin(request)
    if denied:
        return denied

    limit, offset = _parse_limit_offset(request, default_limit=40)
    qs = NonClothingItem.objects.select_related("user", "storage_unit").order_by("-created_at")

    user_id = request.GET.get("user_id")
    if user_id:
        qs = qs.filter(user_id=user_id)

    query = (request.GET.get("q") or "").strip()
    if query:
        qs = qs.filter(
            Q(name__icontains=query)
            | Q(description__icontains=query)
            | Q(user__username__icontains=query)
            | Q(user__email__icontains=query)
            | Q(storage_unit__name__icontains=query)
            | Q(storage_unit__type__icontains=query)
        )

    total = qs.count()
    items = qs[offset : offset + limit]
    results = []
    for item in items:
        payload = NonClothingItemSerializer(item, context={"request": request}).data
        payload["user"] = {
            "id": item.user_id,
            "username": item.user.username,
            "email": item.user.email,
        }
        results.append(payload)

    return Response({"results": results, "total": total, "limit": limit, "offset": offset})


def admin_feedback_list(request):
    denied = _require_admin(request)
    if denied:
        return denied

    limit, offset = _parse_limit_offset(request, default_limit=50)
    qs = BetaFeedback.objects.select_related("user").order_by("-created_at")
    total = qs.count()
    items = qs[offset : offset + limit]
    results = []
    for item in items:
        results.append(
            {
                "id": item.id,
                "message": item.message,
                "rating": item.rating,
                "is_read": item.is_read,
                "created_at": item.created_at.isoformat(),
                "user": {
                    "id": item.user_id,
                    "username": item.user.username,
                    "email": item.user.email,
                },
            }
        )
    return Response({"results": results, "total": total, "limit": limit, "offset": offset})


def admin_feedback_mark_read(request, feedback_id):
    denied = _require_admin(request)
    if denied:
        return denied

    try:
        feedback = BetaFeedback.objects.get(id=feedback_id)
    except BetaFeedback.DoesNotExist:
        return Response({"detail": "Feedback not found."}, status=404)

    feedback.is_read = _as_bool(request.data.get("is_read", True))
    feedback.save(update_fields=["is_read"])
    return Response({"id": feedback.id, "is_read": feedback.is_read})


class AdminViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]

    def dashboard(self, request):
        return admin_dashboard(request)

    def users(self, request):
        return admin_users(request)

    def set_user_active(self, request, user_id=None):
        return admin_set_user_active(request, user_id)

    def set_user_staff(self, request, user_id=None):
        return admin_set_user_staff(request, user_id)

    def user_summary(self, request, user_id=None):
        return admin_user_summary(request, user_id)

    def user_clothing(self, request, user_id=None):
        return admin_user_clothing(request, user_id)

    def user_outfits(self, request, user_id=None):
        return admin_user_outfits(request, user_id)

    def send_password_reset(self, request, user_id=None):
        return admin_send_password_reset(request, user_id)

    def clothing_list(self, request):
        return admin_clothing_list(request)

    def clothing_detail(self, request, item_id=None):
        return admin_clothing_detail(request, item_id)

    def clothing_delete(self, request, item_id=None):
        return admin_clothing_detail(request, item_id)

    def clothing_reclassify(self, request):
        return admin_clothing_reclassify(request)

    def outfits_list(self, request):
        return admin_outfits_list(request)

    def outfit_detail(self, request, outfit_id=None):
        return admin_outfit_detail(request, outfit_id)

    def non_clothing_list(self, request):
        return admin_non_clothing_list(request)

    def feedback_list(self, request):
        return admin_feedback_list(request)

    def feedback_mark_read(self, request, feedback_id=None):
        return admin_feedback_mark_read(request, feedback_id)

