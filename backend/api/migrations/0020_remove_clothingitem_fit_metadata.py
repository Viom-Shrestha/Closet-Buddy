from django.db import migrations


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0019_outfit_ai_rating_snapshot"),
    ]

    operations = [
        migrations.RemoveField(
            model_name="clothingitem",
            name="fit_offset_x",
        ),
        migrations.RemoveField(
            model_name="clothingitem",
            name="fit_offset_y",
        ),
        migrations.RemoveField(
            model_name="clothingitem",
            name="fit_scale",
        ),
    ]
