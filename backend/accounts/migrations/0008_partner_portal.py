from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [("accounts", "0007_business_controls")]
    operations = [
        migrations.AddField(model_name="referralpartner", name="owner_user",
            field=models.OneToOneField(blank=True, null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="referral_partner", to=settings.AUTH_USER_MODEL)),
        migrations.CreateModel(name="PartnerReferralCode", fields=[
            ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
            ("code", models.CharField(max_length=24, unique=True)),
            ("active", models.BooleanField(default=True)),
            ("created_at", models.DateTimeField(auto_now_add=True)),
            ("partner", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                related_name="extra_codes", to="accounts.referralpartner")),
        ]),
    ]
