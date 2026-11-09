from django.test import TestCase
from django.urls import reverse
from rest_framework.test import APIClient
from django.utils import timezone
from datetime import timedelta
from .models import StudentUser

class AccountAccessTests(TestCase):
    def setUp(self):
        self.client=APIClient()
        self.user=StudentUser.objects.create_user(email='student@example.com',password='SafePassword#123',email_verified=True,trial_started_at=timezone.now())
    def test_access_and_profile_are_account_scoped(self):
        from rest_framework_simplejwt.tokens import RefreshToken
        self.client.credentials(HTTP_AUTHORIZATION='Bearer '+str(RefreshToken.for_user(self.user).access_token))
        response=self.client.get('/api/v1/auth/me/')
        self.assertEqual(response.status_code,200)
        self.assertTrue(response.data['academic_access'])
        self.assertEqual(self.client.patch('/api/v1/auth/profile/',{'department':'Engineering'}).status_code,200)
        other=StudentUser.objects.create_user(email='other@example.com',password='SafePassword#123',email_verified=True,trial_started_at=timezone.now())
        self.client.credentials(HTTP_AUTHORIZATION='Bearer '+str(RefreshToken.for_user(other).access_token))
        self.assertEqual(self.client.get('/api/v1/auth/profile/').data['department'],'')
    def test_trial_expiry(self):
        self.user.trial_started_at=timezone.now()-timedelta(days=8)
        self.user.save()
        self.assertFalse(self.user.has_academic_access)
