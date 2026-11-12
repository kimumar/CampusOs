from django.test import TestCase
from rest_framework.test import APIClient
from django.utils import timezone
from .models import StudentUser, AcademicRecord

class AcademicSyncTests(TestCase):
    def setUp(self):
        self.a = StudentUser.objects.create_user(email="a@school.test", password="SafePassword123!",
                                              email_verified=True, trial_started_at=timezone.now(),
                                              trial_expires_at=timezone.now()+__import__("datetime").timedelta(days=3))
        self.b = StudentUser.objects.create_user(email="b@school.test", password="SafePassword123!",
                                              email_verified=True, trial_started_at=timezone.now(),
                                              trial_expires_at=timezone.now()+__import__("datetime").timedelta(days=3))
        self.client = APIClient()
    def test_account_isolation_and_delete_tombstone(self):
        self.client.force_authenticate(user=self.a)
        now = timezone.now().isoformat()
        item = {"id":"course-1", "updated_at":now, "is_deleted":False, "code":"CSC101", "title":"Intro", "units":3}
        url = "/api/v1/auth/academic-records/"
        response = self.client.post(url, {"records":[{"kind":"course","id":"course-1","payload":item}]},format="json")
        self.assertEqual(response.status_code,200)
        self.assertEqual(AcademicRecord.objects.count(),1)
        self.client.force_authenticate(user=self.b)
        self.assertEqual(self.client.get(url).data["records"],[])
        self.client.force_authenticate(user=self.a)
        self.assertEqual(len(self.client.get(url).data["records"]),1)
    def test_reject_malformed_records(self):
        self.client.force_authenticate(user=self.a)
        self.assertEqual(self.client.post("/api/v1/auth/academic-records/",{"records":[{"kind":"course","id":"x","payload":{"id":"wrong"}}]},format="json").status_code,400)
