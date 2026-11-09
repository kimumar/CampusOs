from unittest.mock import patch
from django.test import TestCase, override_settings
from rest_framework.test import APIClient
from .models import StudentUser, EmailVerificationCode
from .verification import digest

@override_settings(DEBUG=True)
class CodeVerificationTests(TestCase):
    def setUp(self):
        self.client=APIClient()
        self.email='otp@example.com'
        self.password='StrongPassword123!'
    @patch('accounts.views.send_code')
    def test_registration_code_verify_once_and_trial(self, send):
        result=self.client.post('/api/v1/auth/register/',{'email':self.email,'password':self.password})
        self.assertEqual(result.status_code,201)
        self.assertEqual(send.call_count,1)
        code=send.call_args.args[1]
        self.assertEqual(len(code),6)
        self.assertNotEqual(EmailVerificationCode.objects.get(user__email=self.email).code_hash,code)
        self.assertEqual(self.client.post('/api/v1/auth/verify-code/',{'email':self.email,'code':'000000' if code!='000000' else '999999'}).status_code,400)
        self.assertEqual(self.client.post('/api/v1/auth/verify-code/',{'email':self.email,'code':code}).status_code,200)
        user=StudentUser.objects.get(email=self.email)
        self.assertTrue(user.email_verified)
        self.assertIsNotNone(user.trial_started_at)
        self.assertEqual(self.client.post('/api/v1/auth/verify-code/',{'email':self.email,'code':code}).status_code,400)
    @patch('accounts.views.send_code')
    def test_resend_cooldown(self, send):
        self.client.post('/api/v1/auth/register/',{'email':self.email,'password':self.password})
        self.client.post('/api/v1/auth/resend-verification/',{'email':self.email})
        self.assertEqual(send.call_count,1)
