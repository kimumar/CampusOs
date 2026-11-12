"""Authoritative eligible user set for community progress (including trial users).

All verified accounts with current academic access participate, including
those without mission data. Names and individual records are never in output.
"""
from datetime import timedelta

from django.db.models import Q
from django.utils import timezone

from .models import StudentUser, StudentProfile


def is_eligible(user):
    return bool(user.is_authenticated and user.is_active and user.has_academic_access)


def eligible_users():
    now = timezone.now()
    return StudentUser.objects.filter(email_verified=True, is_active=True).filter(
        Q(paid_until__gt=now) |
        Q(complimentary_lifetime=True) | Q(complimentary_until__gt=now) |
        Q(trial_expires_at__gt=now) |
        Q(trial_expires_at__isnull=True, trial_started_at__gt=now - timedelta(days=3))
    ).distinct()
