from unittest.mock import patch
from django.test import TestCase, override_settings
from django.urls import reverse
from django.utils.http import urlsafe_base64_encode
from django.utils.encoding import force_bytes
from django.contrib.auth.tokens import default_token_generator
from .models import StudentUser

@override_settings(DEBUG=True, ALLOWED_HOSTS=["testserver", "10.159.57.48"])
class PasswordResetPageTests(TestCase):
    def setUp(self):
        self.user = StudentUser.objects.create_user(email="reset014@example.com", password="OldPassword#123", email_verified=True)

    @patch("accounts.views.send_message")
    def test_reset_email_uses_reachable_server_and_not_flutter_localhost(self, sender):
        response = self.client.post("/api/v1/auth/password-reset/", {"email": self.user.email}, HTTP_HOST="10.159.57.48:8000")
        self.assertEqual(response.status_code, 200)
        body = sender.call_args.args[2]
        self.assertIn("http://10.159.57.48:8000/reset-password/", body)
        self.assertNotIn("localhost:61653", body)

    def test_password_reset_form_and_single_use_token(self):
        uid = urlsafe_base64_encode(force_bytes(self.user.pk))
        token = default_token_generator.make_token(self.user)
        url = reverse("password_reset_page")
        response = self.client.get(url, {"uid": uid, "token": token})
        self.assertContains(response, "Choose a new password")
        response = self.client.post(url, {"uid": uid, "token": token, "password": "NewPassword#123", "confirm": "NewPassword#123"})
        self.assertContains(response, "Password updated")
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password("NewPassword#123"))
        response = self.client.get(url, {"uid": uid, "token": token})
        self.assertContains(response, "Link expired")
