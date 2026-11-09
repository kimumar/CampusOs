"""Six-digit verification codes; never store plaintext codes."""
import hashlib
import hmac
import secrets
from datetime import timedelta
from django.conf import settings
from django.utils import timezone
from .models import EmailVerificationCode

CODE_TTL = timedelta(minutes=10)
RESEND_WAIT = timedelta(seconds=60)
MAX_ATTEMPTS = 5

def digest(user, code):
    payload = f"{user.pk}:{code}".encode()
    return hmac.new(settings.SECRET_KEY.encode(), payload, hashlib.sha256).hexdigest()

def issue(user):
    now = timezone.now()
    existing = EmailVerificationCode.objects.filter(user=user).first()
    if existing and existing.sent_at > now - RESEND_WAIT:
        return None
    code = f"{secrets.randbelow(1000000):06d}"
    EmailVerificationCode.objects.update_or_create(user=user, defaults={
        "code_hash":digest(user,code), "expires_at":now+CODE_TTL,
        "sent_at":now,"attempts":0,
    })
    return code

def check(user, code):
    from django.db import transaction
    with transaction.atomic():
        record = EmailVerificationCode.objects.select_for_update().filter(user=user).first()
        if not record or timezone.now() >= record.expires_at or record.attempts >= MAX_ATTEMPTS:
            return False
        record.attempts += 1
        record.save(update_fields=["attempts"])
        if not hmac.compare_digest(record.code_hash,digest(user,code)):
            return False
        record.delete()
        return True
