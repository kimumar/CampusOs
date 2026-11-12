from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    initial = True
    dependencies = [migrations.swappable_dependency(settings.AUTH_USER_MODEL)]
    operations = [
        migrations.CreateModel(
            name="DailyProgress",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("study_date", models.DateField(db_index=True)),
                ("assigned", models.PositiveSmallIntegerField(default=0)),
                ("completed", models.PositiveSmallIntegerField(default=0)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("user", models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to=settings.AUTH_USER_MODEL)),
            ],
        ),
        migrations.AddConstraint(
            model_name="dailyprogress",
            constraint=models.UniqueConstraint(fields=("user", "study_date"), name="unique_pulse_user_day"),
        ),
        migrations.AddConstraint(
            model_name="dailyprogress",
            constraint=models.CheckConstraint(condition=models.Q(completed__lte=models.F("assigned")), name="pulse_completed_lte_assigned"),
        ),
        migrations.AddConstraint(
            model_name="dailyprogress",
            constraint=models.CheckConstraint(condition=models.Q(assigned__lte=3), name="pulse_max_three_goals"),
        ),
    ]
