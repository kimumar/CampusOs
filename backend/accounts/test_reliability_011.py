"""Regression tests for the shortened trial and password-reset email delivery."""
from datetime import timedelta
from unittest.mock import patch

from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient

from .models import StudentUser


class TrialAndResetTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = StudentUser.objects.create_user(
            email="reliability@example.com", password="SafePassword#123",
            email_verified=True, trial_started_at=timezone.now(),
        )

    def test_trial_last_three_days_not_seven(self):
        self.assertAlmostEqual(
            (self.user.trial_ends_at - self.user.trial_started_at).total_seconds(),
            3 * 24 * 60 * 60,
        )
        self.user.trial_started_at = timezone.now() - timedelta(days=4)
        self.assertFalse(self.user.has_academic_access)

    @override_settings(PASSWORD_RESET_PUBLIC_BASE_URL="https://campusos.test")
    @patch("accounts.views.send_message")
    def test_password_reset_uses_transactional_sender(self, sender):
        response = self.client.post("/api/v1/auth/password-reset/", {
            "email": self.user.email,
        })
        self.assertEqual(response.status_code, 200)
        self.assertEqual(sender.call_count, 1)
        self.assertIn("reset-password", sender.call_args.args[2])

    @patch("accounts.views.send_message", side_effect=RuntimeError("mail unavailable"))
    def test_reset_delivery_failure_is_not_reported_as_success(self, sender):
        response = self.client.post("/api/v1/auth/password-reset/", {
            "email": self.user.email,
        })
        self.assertEqual(response.status_code, 503)
