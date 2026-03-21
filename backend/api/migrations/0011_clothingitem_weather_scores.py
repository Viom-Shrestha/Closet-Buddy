from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0010_remove_outfit_suggestion"),
    ]

    operations = [
        migrations.AddField(
            model_name="clothingitem",
            name="weather_scores",
            field=models.JSONField(blank=True, default=dict),
        ),
    ]
