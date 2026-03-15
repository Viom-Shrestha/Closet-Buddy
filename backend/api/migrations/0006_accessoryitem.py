from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0005_clothingitem_fit_metadata"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="AccessoryItem",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("image", models.ImageField(upload_to="accessories/")),
                ("name", models.CharField(max_length=100)),
                ("description", models.TextField(blank=True, null=True)),
                ("dominant_color", models.CharField(default="Unknown", max_length=30)),
                ("secondary_color", models.CharField(blank=True, max_length=30, null=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("is_favourite", models.BooleanField(default=False)),
                (
                    "storage_unit",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.PROTECT,
                        related_name="accessory_items",
                        to="api.storageunit",
                    ),
                ),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="accessory_items",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
        ),
    ]
