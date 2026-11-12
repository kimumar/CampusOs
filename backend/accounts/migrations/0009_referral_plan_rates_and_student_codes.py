from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


def add_existing_codes(apps, schema_editor):
    from secrets import token_hex
    User = apps.get_model('accounts', 'StudentUser')
    Code = apps.get_model('accounts', 'StudentReferralCode')
    for user in User.objects.all().iterator():
        if Code.objects.filter(user_id=user.pk).exists():
            continue
        for _ in range(8):
            code = 'S' + token_hex(6).upper()
            if not Code.objects.filter(code=code).exists():
                Code.objects.create(user_id=user.pk, code=code)
                break
        else:
            raise RuntimeError('Could not generate unique student invitation code')


class Migration(migrations.Migration):
    dependencies = [('accounts', '0008_partner_portal')]
    operations = [
        migrations.AddField(model_name='referralpartner', name='monthly_commission_override_ngn', field=models.PositiveIntegerField(null=True, blank=True, verbose_name='Monthly referral reward (₦)', help_text='Leave blank to use the standard rate. Set 0 for no reward.')),
        migrations.AddField(model_name='referralpartner', name='quarterly_commission_override_ngn', field=models.PositiveIntegerField(null=True, blank=True, verbose_name='Quarterly referral reward (₦)', help_text='Leave blank to use the standard rate. Set 0 for no reward.')),
        migrations.AddField(model_name='campusbusinesssettings', name='default_referral_quarterly_commission_ngn', field=models.PositiveIntegerField(default=450, verbose_name='Default quarterly referral reward (₦)')),
        migrations.AlterField(model_name='referralpartner', name='commission_override_ngn', field=models.PositiveIntegerField(null=True, blank=True, help_text='Legacy rate for both plans. Prefer the plan-specific rates below.')),
        migrations.AlterField(model_name='campusbusinesssettings', name='default_referral_commission_ngn', field=models.PositiveIntegerField(default=200, verbose_name='Default monthly referral reward (₦)')),
        migrations.CreateModel(name='StudentReferralCode', fields=[
            ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
            ('code', models.CharField(max_length=24, unique=True, db_index=True)),
            ('created_at', models.DateTimeField(auto_now_add=True)),
            ('user', models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name='student_invite', to=settings.AUTH_USER_MODEL)),
        ]),
        migrations.CreateModel(name='StudentReferralAttribution', fields=[
            ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
            ('created_at', models.DateTimeField(auto_now_add=True)),
            ('referrer', models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name='students_invited', to=settings.AUTH_USER_MODEL)),
            ('user', models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name='invited_by_student', to=settings.AUTH_USER_MODEL)),
        ]),
        migrations.RunPython(add_existing_codes, migrations.RunPython.noop),
    ]
