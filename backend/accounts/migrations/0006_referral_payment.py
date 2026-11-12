from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [("accounts", "0005_studentprofile_pulse_opt_in")]
    operations = [
        migrations.CreateModel(name="ReferralPartner", fields=[
            ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
            ("code", models.CharField(max_length=24, unique=True)),
            ("name", models.CharField(max_length=120)),
            ("university", models.CharField(max_length=160)),
            ("active", models.BooleanField(default=True)),
            ("created_at", models.DateTimeField(auto_now_add=True)),
        ]),
        migrations.CreateModel(name="ReferralAttribution", fields=[
            ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
            ("created_at", models.DateTimeField(auto_now_add=True)),
            ("partner", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, to="accounts.referralpartner")),
            ("user", models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, to=settings.AUTH_USER_MODEL)),
        ]),
        migrations.CreateModel(name="SubscriptionPayment", fields=[
            ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
            ("plan", models.CharField(choices=[("monthly", "Monthly ₦700"), ("quarterly", "Quarterly ₦2,000")], max_length=16)),
            ("external_reference", models.CharField(max_length=120, unique=True)),
            ("amount_ngn", models.PositiveIntegerField()),
            ("verified", models.BooleanField(default=False)),
            ("verified_at", models.DateTimeField(blank=True, null=True)),
            ("created_at", models.DateTimeField(auto_now_add=True)),
            ("user", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, to=settings.AUTH_USER_MODEL)),
        ]),
        migrations.CreateModel(name="ReferralReward", fields=[
            ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
            ("amount_ngn", models.PositiveIntegerField(default=200)),
            ("paid_out", models.BooleanField(default=False)),
            ("created_at", models.DateTimeField(auto_now_add=True)),
            ("partner", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, to="accounts.referralpartner")),
            ("payment", models.OneToOneField(on_delete=django.db.models.deletion.PROTECT, to="accounts.subscriptionpayment")),
            ("user", models.OneToOneField(on_delete=django.db.models.deletion.PROTECT, to=settings.AUTH_USER_MODEL)),
        ]),
    ]
