from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0018_remove_outfit_silhouette"),
    ]

    operations = [
        migrations.AddField(
            model_name="outfit",
            name="ai_rated_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="outfit",
            name="ai_rating_breakdown",
            field=models.JSONField(blank=True, default=dict),
        ),
        migrations.AddField(
            model_name="outfit",
            name="ai_rating_reasons",
            field=models.JSONField(blank=True, default=list),
        ),
        migrations.AddField(
            model_name="outfit",
            name="ai_rating_score",
            field=models.FloatField(
                blank=True,
                null=True,
                validators=[MinValueValidator(1.0), MaxValueValidator(5.0)],
            ),
        ),
    ]
