from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("accounts", "0006_referral_payment")]
    operations = [
        migrations.AddField(model_name="studentuser", name="trial_duration_days", field=models.PositiveSmallIntegerField(default=3)),
        migrations.AddField(model_name="studentuser", name="trial_expires_at", field=models.DateTimeField(null=True, blank=True)),
        migrations.AddField(model_name="studentuser", name="complimentary_until", field=models.DateTimeField(null=True, blank=True)),
        migrations.AddField(model_name="studentuser", name="complimentary_lifetime", field=models.BooleanField(default=False)),
        migrations.AddField(model_name="studentuser", name="complimentary_reason", field=models.CharField(max_length=160, blank=True)),
        migrations.AddField(model_name="referralpartner", name="commissions_enabled", field=models.BooleanField(default=True)),
        migrations.AddField(model_name="referralpartner", name="commission_override_ngn", field=models.PositiveIntegerField(null=True, blank=True)),
        migrations.CreateModel(name="CampusBusinessSettings", fields=[
            ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
            ("trial_days", models.PositiveSmallIntegerField(default=3)),
            ("offline_hours", models.PositiveSmallIntegerField(default=24)),
            ("monthly_price_ngn", models.PositiveIntegerField(default=700)),
            ("quarterly_price_ngn", models.PositiveIntegerField(default=2000)),
            ("default_referral_commission_ngn", models.PositiveIntegerField(default=200)),
            ("partner_registration_open", models.BooleanField(default=True)),
            ("announcement", models.CharField(max_length=240, blank=True)),
        ]),
    ]
