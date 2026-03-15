from django.db import migrations, models
import django.core.validators


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0004_outfit_slots_and_silhouette"),
    ]

    operations = [
        migrations.AddField(
            model_name="clothingitem",
            name="fit_offset_x",
            field=models.FloatField(
                default=0.0,
                validators=[
                    django.core.validators.MinValueValidator(-1.0),
                    django.core.validators.MaxValueValidator(1.0),
                ],
            ),
        ),
        migrations.AddField(
            model_name="clothingitem",
            name="fit_offset_y",
            field=models.FloatField(
                default=0.0,
                validators=[
                    django.core.validators.MinValueValidator(-1.0),
                    django.core.validators.MaxValueValidator(1.0),
                ],
            ),
        ),
        migrations.AddField(
            model_name="clothingitem",
            name="fit_scale",
            field=models.FloatField(
                default=1.0,
                validators=[
                    django.core.validators.MinValueValidator(0.5),
                    django.core.validators.MaxValueValidator(2.0),
                ],
            ),
        ),
    ]
