from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0006_accessoryitem"),
    ]

    operations = [
        migrations.AddField(
            model_name="accessoryitem",
            name="dominant_color",
            field=models.CharField(default="Unknown", max_length=30),
        ),
        migrations.AddField(
            model_name="accessoryitem",
            name="secondary_color",
            field=models.CharField(blank=True, max_length=30, null=True),
        ),
        migrations.AddField(
            model_name="outfit",
            name="outerwear",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="as_outerwear_in_outfits",
                to="api.clothingitem",
            ),
        ),
        migrations.AddField(
            model_name="outfit",
            name="preview_layout",
            field=models.JSONField(blank=True, default=dict),
        ),
        migrations.AddField(
            model_name="outfit",
            name="accessories",
            field=models.ManyToManyField(blank=True, related_name="outfits", to="api.accessoryitem"),
        ),
    ]
