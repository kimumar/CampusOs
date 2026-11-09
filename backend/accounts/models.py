import uuid
from datetime import timedelta
from django.conf import settings
from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.db import models
from django.utils import timezone

class StudentUserManager(BaseUserManager):
    def create_user(self, email, password=None, **extra):
        if not email:
            raise ValueError("Email is required")
        email = self.normalize_email(email).strip().lower()
        user = self.model(email=email, **extra)
        user.set_password(password)
        user.save(using=self._db)
        return user
    def create_superuser(self, email, password=None, **extra):
        extra.setdefault("is_staff", True)
        extra.setdefault("is_superuser", True)
        extra.setdefault("is_active", True)
        extra.setdefault("email_verified", True)
        if not extra["is_staff"] or not extra["is_superuser"]:
            raise ValueError("Superuser must have staff and superuser privileges")
        return self.create_user(email, password, **extra)

class StudentUser(AbstractUser):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    username = None
    email = models.EmailField(unique=True)
    email_verified = models.BooleanField(default=False)
    trial_started_at = models.DateTimeField(null=True, blank=True)
    paid_until = models.DateTimeField(null=True, blank=True)
    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = []
    objects = StudentUserManager()
    @property
    def trial_ends_at(self):
        return self.trial_started_at + timedelta(days=7) if self.trial_started_at else None
    @property
    def has_academic_access(self):
        now = timezone.now()
        return self.email_verified and (
            (self.trial_ends_at is not None and now < self.trial_ends_at)
            or (self.paid_until is not None and now < self.paid_until)
        )

class StudentProfile(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="student_profile")
    preferred_name = models.CharField(max_length=100, blank=True)
    institution_type = models.CharField(max_length=60, blank=True)
    institution = models.CharField(max_length=200, blank=True)
    department = models.CharField(max_length=150, blank=True)
    level = models.CharField(max_length=40, blank=True)
    updated_at = models.DateTimeField(auto_now=True)


class EmailVerificationCode(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="verification_code")
    code_hash = models.CharField(max_length=64)
    sent_at = models.DateTimeField()
    expires_at = models.DateTimeField()
    attempts = models.PositiveSmallIntegerField(default=0)

from .cloud_models import AcademicRecord
