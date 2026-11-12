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
    trial_duration_days = models.PositiveSmallIntegerField(default=3)
    trial_expires_at = models.DateTimeField(null=True, blank=True)
    paid_until = models.DateTimeField(null=True, blank=True)
    complimentary_until = models.DateTimeField(null=True, blank=True)
    complimentary_lifetime = models.BooleanField(default=False)
    complimentary_reason = models.CharField(max_length=160, blank=True)
    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = []
    objects = StudentUserManager()
    @property
    def trial_ends_at(self):
        return self.trial_expires_at or (
            self.trial_started_at + timedelta(days=self.trial_duration_days) if self.trial_started_at else None)
    @property
    def has_complimentary_access(self):
        return self.complimentary_lifetime or (
            self.complimentary_until is not None and self.complimentary_until > timezone.now())
    @property
    def has_academic_access(self):
        now = timezone.now()
        return self.email_verified and (
            (self.trial_ends_at is not None and now < self.trial_ends_at)
            or (self.paid_until is not None and now < self.paid_until)
            or self.has_complimentary_access
        )

class StudentProfile(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="student_profile")
    preferred_name = models.CharField(max_length=100, blank=True)
    institution_type = models.CharField(max_length=60, blank=True)
    institution = models.CharField(max_length=200, blank=True)
    department = models.CharField(max_length=150, blank=True)
    level = models.CharField(max_length=40, blank=True)
    pulse_opt_in = models.BooleanField(default=False)
    updated_at = models.DateTimeField(auto_now=True)


class EmailVerificationCode(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="verification_code")
    code_hash = models.CharField(max_length=64)
    sent_at = models.DateTimeField()
    expires_at = models.DateTimeField()
    attempts = models.PositiveSmallIntegerField(default=0)

from .cloud_models import AcademicRecord


class SupportTicket(models.Model):
    """Small, private support messages visible to CampusOS administrators."""
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    category = models.CharField(max_length=32)
    message = models.TextField(max_length=1500)
    created_at = models.DateTimeField(auto_now_add=True)
    is_resolved = models.BooleanField(default=False)

    class Meta:
        ordering = ["-created_at"]


class ReferralPartner(models.Model):
    """One identifiable, active promotional partner per tracking code."""
    code = models.CharField(max_length=24, unique=True)
    name = models.CharField(max_length=120)
    university = models.CharField(max_length=160)
    owner_user = models.OneToOneField(settings.AUTH_USER_MODEL, null=True, blank=True,
                                      on_delete=models.SET_NULL, related_name="referral_partner")
    active = models.BooleanField(default=True)
    commissions_enabled = models.BooleanField(default=True)
    commission_override_ngn = models.PositiveIntegerField(null=True, blank=True, help_text="Legacy rate for both plans. Prefer the plan-specific rates below.")
    monthly_commission_override_ngn = models.PositiveIntegerField(null=True, blank=True, verbose_name="Monthly referral reward (₦)", help_text="Leave blank to use the standard rate. Set 0 for no reward.")
    quarterly_commission_override_ngn = models.PositiveIntegerField(null=True, blank=True, verbose_name="Quarterly referral reward (₦)", help_text="Leave blank to use the standard rate. Set 0 for no reward.")
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.code} · {self.name}"


class PartnerReferralCode(models.Model):
    """Optional extra custom codes; old aliases can remain valid when rebranding."""
    code = models.CharField(max_length=24, unique=True)
    partner = models.ForeignKey(ReferralPartner, on_delete=models.CASCADE,
                                related_name="extra_codes")
    active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)


class ReferralAttribution(models.Model):
    """Immutable initial referral; one attribution per student."""
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    partner = models.ForeignKey(ReferralPartner, on_delete=models.PROTECT)
    created_at = models.DateTimeField(auto_now_add=True)


class SubscriptionPayment(models.Model):
    """Audit record. Only a trusted staff verification activates entitlement."""
    PLAN_CHOICES = [("monthly", "Monthly ₦700"), ("quarterly", "Quarterly ₦2,000")]
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT)
    plan = models.CharField(max_length=16, choices=PLAN_CHOICES)
    external_reference = models.CharField(max_length=120, unique=True)
    amount_ngn = models.PositiveIntegerField()
    verified = models.BooleanField(default=False)
    verified_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)


class ReferralReward(models.Model):
    """A single first-paid-conversion reward per student, frozen at payment verification."""
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.PROTECT)
    partner = models.ForeignKey(ReferralPartner, on_delete=models.PROTECT)
    payment = models.OneToOneField(SubscriptionPayment, on_delete=models.PROTECT)
    amount_ngn = models.PositiveIntegerField(default=200)
    paid_out = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)


class CampusBusinessSettings(models.Model):
    """Singleton configuration editable by the owner through Django Admin."""
    trial_days = models.PositiveSmallIntegerField(default=3)
    offline_hours = models.PositiveSmallIntegerField(default=24)
    monthly_price_ngn = models.PositiveIntegerField(default=700)
    quarterly_price_ngn = models.PositiveIntegerField(default=2000)
    default_referral_commission_ngn = models.PositiveIntegerField(default=200, verbose_name="Default monthly referral reward (₦)")
    default_referral_quarterly_commission_ngn = models.PositiveIntegerField(default=450, verbose_name="Default quarterly referral reward (₦)")
    partner_registration_open = models.BooleanField(default=True)
    announcement = models.CharField(max_length=240, blank=True)

    @classmethod
    def current(cls):
        obj, _ = cls.objects.get_or_create(pk=1)
        return obj


class StudentReferralCode(models.Model):
    """Student invitation identity. It never earns a cash commission."""
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                related_name="student_invite")
    code = models.CharField(max_length=24, unique=True, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)


class StudentReferralAttribution(models.Model):
    """Private and immutable; no reward is generated for this attribution."""
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                related_name="invited_by_student")
    referrer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT,
                                 related_name="students_invited")
    created_at = models.DateTimeField(auto_now_add=True)
