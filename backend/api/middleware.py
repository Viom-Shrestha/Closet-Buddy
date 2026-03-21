from datetime import timedelta

from django.utils import timezone

from .models import UserActivityDaily


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

        activity, created = UserActivityDaily.objects.get_or_create(
            user=user,
            date=now.date(),
            defaults={
                "last_seen_at": now,
                "session_count": 1,
                "total_session_seconds": 0,
            },
        )

        if created:
            return response

        last_seen = activity.last_seen_at
        if last_seen is None:
            activity.session_count += 1
        else:
            delta = (now - last_seen).total_seconds()
            if delta > timedelta(minutes=30).total_seconds():
                activity.session_count += 1
            else:
                activity.total_session_seconds += int(delta)

        activity.last_seen_at = now
        activity.save(update_fields=["last_seen_at", "session_count", "total_session_seconds"])

        return response
