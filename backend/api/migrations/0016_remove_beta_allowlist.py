from django.db import migrations


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0015_userprofile"),
    ]

    operations = [
        migrations.DeleteModel(
            name="BetaAllowlist",
        ),
    ]
