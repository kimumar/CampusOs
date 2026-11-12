from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("accounts", "0004_supportticket")]
    operations = [
        migrations.AddField(model_name="studentprofile", name="pulse_opt_in",
                            field=models.BooleanField(default=False)),
    ]
