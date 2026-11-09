from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion

class Migration(migrations.Migration):
    dependencies = [('accounts','0001_initial')]
    operations = [migrations.CreateModel(name='EmailVerificationCode',fields=[
        ('id',models.BigAutoField(auto_created=True,primary_key=True,serialize=False,verbose_name='ID')),
        ('code_hash',models.CharField(max_length=64)),
        ('sent_at',models.DateTimeField()),
        ('expires_at',models.DateTimeField()),
        ('attempts',models.PositiveSmallIntegerField(default=0)),
        ('user',models.OneToOneField(on_delete=django.db.models.deletion.CASCADE,related_name='verification_code',to=settings.AUTH_USER_MODEL)),
    ])]
