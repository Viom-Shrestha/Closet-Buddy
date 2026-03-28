from django.db import migrations, models


def _forward_copy_daily_activity(apps, schema_editor):
    UserProfile = apps.get_model("api", "UserProfile")
    UserActivityDaily = apps.get_model("api", "UserActivityDaily")

    for entry in UserActivityDaily.objects.all().iterator():
        profile, _ = UserProfile.objects.get_or_create(user_id=entry.user_id)
        activity_daily = profile.activity_daily or {}
        if not isinstance(activity_daily, dict):
            activity_daily = {}
        activity_daily[entry.date.isoformat()] = {
            "last_seen_at": entry.last_seen_at.isoformat() if entry.last_seen_at else None,
            "session_count": int(entry.session_count or 0),
            "total_session_seconds": int(entry.total_session_seconds or 0),
        }
        profile.activity_daily = activity_daily
        profile.save(update_fields=["activity_daily"])


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0016_remove_beta_allowlist"),
    ]

    operations = [
        migrations.AddField(
            model_name="userprofile",
            name="activity_daily",
            field=models.JSONField(blank=True, default=dict),
        ),
        migrations.RunPython(_forward_copy_daily_activity, migrations.RunPython.noop),
        migrations.DeleteModel(
            name="UserActivityDaily",
        ),
    ]
