from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0003_clothingitem_attributes"),
    ]

    operations = [
        migrations.AddField(
            model_name="outfit",
            name="bottomwear",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="as_bottomwear_in_outfits",
                to="api.clothingitem",
            ),
        ),
        migrations.AddField(
            model_name="outfit",
            name="shoes",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="as_shoes_in_outfits",
                to="api.clothingitem",
            ),
        ),
        migrations.AddField(
            model_name="outfit",
            name="silhouette",
            field=models.CharField(
                choices=[("male", "Male"), ("female", "Female")],
                default="male",
                max_length=10,
            ),
        ),
        migrations.AddField(
            model_name="outfit",
            name="topwear",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="as_topwear_in_outfits",
                to="api.clothingitem",
            ),
        ),
    ]
