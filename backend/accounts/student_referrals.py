"""Unrewarded student invitations; never expose invitee identities to other students."""
import secrets
from django.db import IntegrityError, transaction
from .models import StudentReferralCode


def ensure_code(user):
    current = StudentReferralCode.objects.filter(user=user).first()
    if current:
        return current
    for _ in range(6):
        try:
            with transaction.atomic():
                return StudentReferralCode.objects.create(
                    user=user, code="S" + secrets.token_hex(6).upper())
        except IntegrityError:
            current = StudentReferralCode.objects.filter(user=user).first()
            if current:
                return current
    raise RuntimeError("Unable to create student invitation code")
