from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion

class Migration(migrations.Migration):
    dependencies = [("accounts", "0002_emailverificationcode"), migrations.swappable_dependency(settings.AUTH_USER_MODEL)]
    operations = [migrations.CreateModel(name="AcademicRecord", fields=[
        ("id", models.BigAutoField(primary_key=True, serialize=False)),
        ("kind", models.CharField(max_length=16, choices=[("course", "Course"), ("lecture", "Lecture")])),
        ("record_id", models.CharField(max_length=100)),
        ("payload", models.JSONField(default=dict)),
        ("modified_at", models.DateTimeField()),
        ("is_deleted", models.BooleanField(default=False)),
        ("user", models.ForeignKey(to=settings.AUTH_USER_MODEL, on_delete=django.db.models.deletion.CASCADE, related_name="academic_records")),
    ]), migrations.AddConstraint(model_name="academicrecord", constraint=models.UniqueConstraint(fields=("user", "kind", "record_id"), name="unique_academic_record_per_user"))]
