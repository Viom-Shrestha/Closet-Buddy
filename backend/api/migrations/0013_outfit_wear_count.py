from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0012_weather_string_fields"),
    ]

    operations = [
        migrations.AddField(
            model_name="outfit",
            name="wear_count",
            field=models.IntegerField(default=0),
        ),
    ]
