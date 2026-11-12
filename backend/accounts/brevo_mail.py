"""Server-side Brevo transactional email. API keys never reach Flutter."""
import json
import os
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError
from django.core.mail import send_mail
from django.core.exceptions import ImproperlyConfigured

def send_message(email, subject, body):
    sender = os.environ.get("BREVO_SENDER_EMAIL", "campusos.official.ng@gmail.com")
    key = os.environ.get("BREVO_API_KEY", "").strip()
    if not key:
        # Local tests and development only. Production must configure Brevo.
        from django.conf import settings
        if not settings.DEBUG and not os.environ.get('CAMPUSOS_TEST_EMAIL_FALLBACK'):
            raise ImproperlyConfigured('BREVO_API_KEY is required for verification email delivery.')
        send_mail(subject, body, sender, [email], fail_silently=False)
        return
    payload = {"sender":{"name":"CampusOS","email":sender},
               "to":[{"email":email}],"subject":subject,
               "textContent":body}
    req = Request("https://api.brevo.com/v3/smtp/email", data=json.dumps(payload).encode(),
                  headers={"api-key":key,"Content-Type":"application/json","accept":"application/json"},method="POST")
    try:
        with urlopen(req, timeout=15) as response:
            if response.status not in (200,201,202):
                raise RuntimeError('Brevo did not accept the email.')
    except (HTTPError,URLError) as exc:
        raise RuntimeError('Verification email could not be delivered. Check Brevo sender and API configuration.') from exc

def send_code(email, code):
    send_message(email, "Your CampusOS verification code",
                 f"Your CampusOS verification code is {code}. It expires in 10 minutes. If you did not request this, ignore this email.")
