from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0013_outfit_wear_count"),
    ]

    operations = [
        migrations.AddField(
            model_name="outfit",
            name="last_worn_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]
