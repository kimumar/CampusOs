"""Regression tests for the final Campus Pulse inclusion policy."""
from datetime import timedelta
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient
from campus_pulse.models import DailyProgress
from .models import StudentUser, StudentProfile
from .pulse_access import eligible_users

class AutomaticPulseTests(TestCase):
    def setUp(self):
        self.active = StudentUser.objects.create_user(
            email='active-pulse@example.test', password='SafePassword123!',
            email_verified=True, trial_started_at=timezone.now())
        self.inactive = StudentUser.objects.create_user(
            email='expired-pulse@example.test', password='SafePassword123!',
            email_verified=True, trial_started_at=timezone.now() - timedelta(days=15))
        StudentProfile.objects.get_or_create(user=self.active, defaults={'pulse_opt_in': False})
        self.client = APIClient()
        self.client.force_authenticate(user=self.active)

    def test_opt_in_flag_does_not_exclude_eligible_student(self):
        self.assertIn(self.active, eligible_users())
        DailyProgress.objects.create(user=self.active, study_date=timezone.localdate(),
                                     assigned=3, completed=3)
        response = self.client.get('/api/v1/auth/community-pulse/today/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['percent_100'], 100)
        self.assertNotIn('total_subscribers', response.json())

    def test_expired_student_excluded_and_no_activity_means_zero(self):
        self.assertNotIn(self.inactive, eligible_users())
        response = self.client.get('/api/v1/auth/community-pulse/today/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['percent_100'], 0)

    def test_unpaid_cannot_access_pulse(self):
        self.client.force_authenticate(user=self.inactive)
        self.assertEqual(self.client.get('/api/v1/auth/community-pulse/today/').status_code, 403)

    def test_expired_student_cannot_read_or_write_cloud_records(self):
        self.client.force_authenticate(user=self.inactive)
        url = '/api/v1/auth/academic-records/'
        self.assertEqual(self.client.get(url).status_code, 403)
        self.assertEqual(self.client.post(url, {'records': []}, format='json').status_code, 403)
