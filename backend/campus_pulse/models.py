from django.conf import settings
from django.db import models


class DailyProgress(models.Model):
    """One authorized subscriber's latest snapshot per calendar day."""

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    study_date = models.DateField(db_index=True)
    assigned = models.PositiveSmallIntegerField(default=0)
    completed = models.PositiveSmallIntegerField(default=0)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=("user", "study_date"), name="unique_pulse_user_day"),
            models.CheckConstraint(condition=models.Q(completed__lte=models.F("assigned")), name="pulse_completed_lte_assigned"),
            models.CheckConstraint(condition=models.Q(assigned__lte=3), name="pulse_max_three_goals"),
        ]
