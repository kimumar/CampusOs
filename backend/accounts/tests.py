from datetime import timedelta
from django.test import TestCase, override_settings
from django.core.cache import cache
from django.utils import timezone
from .tokens import email_verification_token
from django.utils.http import urlsafe_base64_encode
from django.utils.encoding import force_bytes
from rest_framework.test import APIClient
from .models import StudentUser

@override_settings(EMAIL_BACKEND="django.core.mail.backends.locmem.EmailBackend")
class AccountTests(TestCase):
    def setUp(self):
        # Isolate shared DRF throttle cache between unrelated test cases.
        cache.clear()
        self.client = APIClient()
        self.email = "student@example.com"
        self.password = "ComplexPassword!42"
    def register(self):
        return self.client.post("/api/v1/auth/register/", {"email":self.email,"password":self.password})
    def verify(self):
        user = StudentUser.objects.get(email=self.email)
        return self.client.post("/api/v1/auth/verify-email/", {
            "uid":urlsafe_base64_encode(force_bytes(user.pk)),
            "token":email_verification_token.make_token(user),
        })
    def test_register_verify_login_trial(self):
        self.assertEqual(self.register().status_code, 201)
        self.assertEqual(self.client.post("/api/v1/auth/login/", {"email":self.email,"password":self.password}).status_code, 403)
        self.assertEqual(self.verify().status_code, 200)
        login = self.client.post("/api/v1/auth/login/", {"email":self.email,"password":self.password})
        self.assertEqual(login.status_code, 200)
        self.client.credentials(HTTP_AUTHORIZATION="Bearer "+login.data["access"])
        me = self.client.get("/api/v1/auth/me/")
        self.assertTrue(me.data["academic_access"])
        self.assertIsNotNone(me.data["trial_ends_at"])
        user = StudentUser.objects.get(email=self.email)
        started = user.trial_started_at
        self.assertEqual(self.verify().status_code, 400)
        user.refresh_from_db()
        self.assertEqual(started, user.trial_started_at)
    def test_trial_expires_without_deleting_profile(self):
        self.register()
        self.verify()
        user = StudentUser.objects.get(email=self.email)
        user.trial_started_at = timezone.now() - timedelta(days=8)
        user.trial_expires_at = user.trial_started_at + timedelta(days=user.trial_duration_days)
        user.save()
        self.assertFalse(user.has_academic_access)
        self.assertTrue(hasattr(user, "student_profile"))
    def test_account_profile_isolation(self):
        self.register()
        self.verify()
        a = StudentUser.objects.get(email=self.email)
        b = StudentUser.objects.create_user(email="other@example.com",password=self.password,email_verified=True)
        from .models import StudentProfile
        StudentProfile.objects.create(user=b)
        self.assertNotEqual(a.pk,b.pk)
        self.client.force_authenticate(user=a)
        self.client.patch("/api/v1/auth/profile/", {"department":"Computer Science"})
        self.client.force_authenticate(user=b)
        self.assertEqual(self.client.get("/api/v1/auth/profile/").data["department"], "")
    def test_password_reset_no_account_enumeration(self):
        self.assertEqual(self.client.post("/api/v1/auth/password-reset/", {"email":"missing@example.com"}).status_code,200)

    def test_reused_verification_link_is_rejected(self):
        self.register()
        user = StudentUser.objects.get(email=self.email)
        payload = {
            "uid": urlsafe_base64_encode(force_bytes(user.pk)),
            "token": email_verification_token.make_token(user),
        }
        self.assertEqual(self.client.post("/api/v1/auth/verify-email/", payload).status_code, 200)
        user.refresh_from_db()
        original_start = user.trial_started_at
        self.assertEqual(self.client.post("/api/v1/auth/verify-email/", payload).status_code, 400)
        user.refresh_from_db()
        self.assertEqual(user.trial_started_at, original_start)

    def test_invalid_verification_token_is_rejected(self):
        self.register()
        user = StudentUser.objects.get(email=self.email)
        response = self.client.post("/api/v1/auth/verify-email/", {
            "uid": urlsafe_base64_encode(force_bytes(user.pk)),
            "token": "invalid-token",
        })
        self.assertEqual(response.status_code, 400)
        user.refresh_from_db()
        self.assertFalse(user.email_verified)
        self.assertIsNone(user.trial_started_at)
