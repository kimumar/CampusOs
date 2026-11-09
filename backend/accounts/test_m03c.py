from django.test import TestCase, override_settings
from django.core.exceptions import ValidationError
from django.contrib.auth.password_validation import validate_password
from django.urls import reverse
from .models import StudentUser

class AdminAndPasswordTests(TestCase):
    def test_password_complexity(self):
        for password in ("alllowercase123!", "ALLUPPERCASE123!", "NoNumbersHere!", "NoSymbolsHere123", "Short1!"):
            with self.subTest(password=password):
                with self.assertRaises(ValidationError):
                    validate_password(password)
        validate_password("StrongPassword123!")
    def test_admin_is_protected(self):
        response=self.client.get("/admin/")
        self.assertEqual(response.status_code,302)
        self.assertIn("/admin/login/",response.url)
    def test_admin_login_available(self):
        self.assertEqual(self.client.get("/admin/login/").status_code,200)
