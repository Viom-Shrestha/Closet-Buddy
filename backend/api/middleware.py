from datetime import date, timedelta

from django.utils.dateparse import parse_datetime
from django.utils import timezone

from .models import UserProfile


def _safe_int(value, default=0):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _prune_activity(activity_daily, now, keep_days=90):
    cutoff = now.date() - timedelta(days=keep_days)
    pruned = {}
    for date_key, payload in (activity_daily or {}).items():
        try:
            day = date.fromisoformat(date_key)
        except ValueError:
            continue
        if day >= cutoff:
            pruned[date_key] = payload
    return pruned


class ActivityTrackingMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)

        user = getattr(request, "user", None)
        if not user or not user.is_authenticated:
            return response

        now = timezone.now()
        user.last_login = now
        user.save(update_fields=["last_login"])

        profile, _ = UserProfile.objects.get_or_create(user=user)
        activity_daily = profile.activity_daily or {}
        if not isinstance(activity_daily, dict):
            activity_daily = {}

        today_key = now.date().isoformat()
        day_stats = activity_daily.get(today_key)

        if not isinstance(day_stats, dict):
            activity_daily[today_key] = {
                "last_seen_at": now.isoformat(),
                "session_count": 1,
                "total_session_seconds": 0,
            }
            profile.activity_daily = _prune_activity(activity_daily, now)
            profile.save(update_fields=["activity_daily"])
            return response

        last_seen_raw = day_stats.get("last_seen_at")
        last_seen = parse_datetime(last_seen_raw) if isinstance(last_seen_raw, str) else None
        session_count = _safe_int(day_stats.get("session_count"), default=0)
        total_seconds = _safe_int(day_stats.get("total_session_seconds"), default=0)

        if last_seen is None:
            session_count += 1
        else:
            delta = (now - last_seen).total_seconds()
            if delta > timedelta(minutes=30).total_seconds():
                session_count += 1
            else:
                total_seconds += max(0, int(delta))

        activity_daily[today_key] = {
            "last_seen_at": now.isoformat(),
            "session_count": session_count,
            "total_session_seconds": total_seconds,
        }
        profile.activity_daily = _prune_activity(activity_daily, now)
        profile.save(update_fields=["activity_daily"])

        return response
