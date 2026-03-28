from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0017_profile_activity_daily_and_remove_useractivitydaily"),
    ]

    operations = [
        migrations.RemoveField(
            model_name="outfit",
            name="silhouette",
        ),
    ]
