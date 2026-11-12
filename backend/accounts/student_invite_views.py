from urllib.parse import urlencode
from django.conf import settings
from django.http import Http404
from django.shortcuts import redirect
from django.views.decorators.http import require_GET
from .models import StudentReferralCode

@require_GET
def invite_redirect(request, code):
    normalized = code.strip().upper()
    if not StudentReferralCode.objects.filter(code=normalized).exists():
        raise Http404("Invitation is unavailable")
    # Never redirect to a caller-provided URL.
    return redirect(settings.FRONTEND_URL.rstrip('/') + '/?' + urlencode({'ref': normalized}))
