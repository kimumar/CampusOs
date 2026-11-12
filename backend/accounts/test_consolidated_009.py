"""Regression checks for durable study records, first-user Pulse and support."""
from datetime import timedelta

from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from campus_pulse.models import DailyProgress
from .models import StudentUser, StudentProfile, AcademicRecord, SupportTicket


class ConsolidatedTests(TestCase):
    def setUp(self):
        self.user = StudentUser.objects.create_user(
            email="first@campus.test", password="SafePassword123!",
            email_verified=True, trial_started_at=timezone.now(),
        )
        self.other = StudentUser.objects.create_user(
            email="other@campus.test", password="SafePassword123!",
            email_verified=True, trial_started_at=timezone.now() - timedelta(days=10),
        )
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)
        profile, _ = StudentProfile.objects.get_or_create(user=self.user)
        profile.pulse_opt_in = True
        profile.save(update_fields=["pulse_opt_in"])

    def test_first_eligible_user_counts_in_pulse(self):
        today = timezone.localdate()
        DailyProgress.objects.create(user=self.user, study_date=today, assigned=3, completed=3)
        response = self.client.get("/api/v1/auth/community-pulse/today/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["percent_100"], 100)
        self.assertEqual(response.json()["percent_90"], 100)
        self.assertEqual(response.json()["percent_50"], 100)
        self.assertNotIn("total_subscribers", response.json())

    def test_one_user_no_activity_is_zero_not_full_completion(self):
        response = self.client.get("/api/v1/auth/community-pulse/today/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["percent_100"], 0)

    def test_note_and_recall_account_isolation(self):
        url = "/api/v1/auth/academic-records/"
        now = timezone.now().isoformat()
        records = [
            {"kind": "lesson_note", "id": "n1", "payload": {
                "id": "n1", "text": "Private semester notes", "updated_at": now}},
            {"kind": "recall_session", "id": "r1", "payload": {
                "id": "r1", "session_id": "r1", "questions": [], "updated_at": now}},
        ]
        response = self.client.post(url, {"records": records}, format="json")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(AcademicRecord.objects.filter(user=self.user).count(), 2)
        self.client.force_authenticate(user=self.other)
        blocked = self.client.get(url)
        self.assertEqual(blocked.status_code, 403)
        self.assertNotIn("records", blocked.data)

    def test_support_submission(self):
        response = self.client.post("/api/v1/auth/support-tickets/", {
            "category": "bug", "message": "My saved study note did not load after login."}, format="json")
        self.assertEqual(response.status_code, 201)
        self.assertEqual(SupportTicket.objects.filter(user=self.user).count(), 1)

    def test_support_rejects_invalid_category(self):
        response = self.client.post("/api/v1/auth/support-tickets/", {
            "category": "admin", "message": "An unwanted privileged category"}, format="json")
        self.assertEqual(response.status_code, 400)
