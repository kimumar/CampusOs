from django.conf import settings
from django.db import models

class AcademicRecord(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="academic_records")
    kind = models.CharField(max_length=16, choices=[("course", "Course"), ("lecture", "Lecture")])
    record_id = models.CharField(max_length=100)
    payload = models.JSONField(default=dict)
    modified_at = models.DateTimeField()
    is_deleted = models.BooleanField(default=False)
    class Meta:
        constraints = [models.UniqueConstraint(fields=["user", "kind", "record_id"], name="unique_academic_record_per_user")]
