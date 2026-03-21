from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0011_clothingitem_weather_scores"),
    ]

    operations = [
        migrations.RemoveField(
            model_name="clothingitem",
            name="weather_scores",
        ),
        migrations.AddField(
            model_name="clothingitem",
            name="detected_temp",
            field=models.CharField(blank=True, max_length=30, null=True),
        ),
        migrations.AddField(
            model_name="clothingitem",
            name="detected_weather",
            field=models.CharField(blank=True, max_length=30, null=True),
        ),
    ]
