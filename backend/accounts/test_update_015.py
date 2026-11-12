from django.test import TestCase
from django.urls import reverse
from django.utils import timezone
from .models import (StudentUser, CampusBusinessSettings, ReferralPartner, ReferralAttribution,
                     SubscriptionPayment, ReferralReward, StudentReferralCode, StudentReferralAttribution)
from .subscription_service import verify_recorded_payment
from .student_referrals import ensure_code


class PlanRewards015Tests(TestCase):
    def setUp(self):
        self.owner = StudentUser.objects.create_user(email='owner015@example.com', password='StrongPass015#', email_verified=True)
        self.partner = ReferralPartner.objects.create(code='TV015', name='TV', university='FUTA', owner_user=self.owner)
        self.student = StudentUser.objects.create_user(email='student015@example.com', password='StrongPass015#', email_verified=True)
        ReferralAttribution.objects.create(user=self.student, partner=self.partner)

    def payment(self, plan, reference):
        amount = 700 if plan == 'monthly' else 2000
        return SubscriptionPayment.objects.create(user=self.student, plan=plan, amount_ngn=amount, external_reference=reference)

    def test_default_monthly_reward_200(self):
        verify_recorded_payment(self.payment('monthly','015m').pk)
        self.assertEqual(ReferralReward.objects.get(user=self.student).amount_ngn, 200)

    def test_default_quarterly_reward_450(self):
        verify_recorded_payment(self.payment('quarterly','015q').pk)
        self.assertEqual(ReferralReward.objects.get(user=self.student).amount_ngn, 450)

    def test_individual_rates_and_no_reward_at_zero(self):
        self.partner.monthly_commission_override_ngn = 0
        self.partner.quarterly_commission_override_ngn = 650
        self.partner.save()
        verify_recorded_payment(self.payment('monthly','015m0').pk)
        self.assertFalse(ReferralReward.objects.filter(user=self.student).exists())

    def test_quarterly_override_does_not_reprice_earned_reward(self):
        self.partner.quarterly_commission_override_ngn = 650
        self.partner.save()
        verify_recorded_payment(self.payment('quarterly','015q1').pk)
        self.partner.quarterly_commission_override_ngn = 0
        self.partner.save()
        self.assertEqual(ReferralReward.objects.get(user=self.student).amount_ngn, 650)

    def test_no_reward_on_renewal(self):
        verify_recorded_payment(self.payment('monthly','015first').pk)
        verify_recorded_payment(self.payment('quarterly','015renew').pk)
        self.assertEqual(ReferralReward.objects.filter(user=self.student).count(),1)

    def test_owner_dashboard_requires_superuser(self):
        self.owner.is_staff = True
        self.owner.save(update_fields=['is_staff'])
        self.client.force_login(self.owner)
        self.assertEqual(self.client.get('/control/').status_code,403)
        self.owner.is_superuser = True
        self.owner.is_staff = True
        self.owner.save()
        self.assertEqual(self.client.get('/control/').status_code,200)


class StudentInvitesAndPassword015Tests(TestCase):
    def setUp(self):
        self.referrer = StudentUser.objects.create_user(email='refer015@example.com', password='StrongPass015#', email_verified=True)
        self.student = StudentUser.objects.create_user(email='invite015@example.com', password='StrongPass015#', email_verified=True)

    def test_unique_codes_and_no_cash_reward(self):
        first = ensure_code(self.referrer)
        second = ensure_code(self.student)
        self.assertNotEqual(first.code, second.code)
        self.assertEqual(first.code, ensure_code(self.referrer).code)
        StudentReferralAttribution.objects.create(user=self.student, referrer=self.referrer)
        self.client.force_login(self.referrer)
        # DRF uses JWT not session; use force_authenticate for token-protected endpoints below.
        from rest_framework.test import APIClient
        api = APIClient()
        api.force_authenticate(user=self.referrer)
        result = api.get('/api/v1/auth/my-invitation/')
        self.assertEqual(result.status_code,200)
        self.assertEqual(result.data['invitation_count'],1)
        self.assertEqual(result.data['cash_reward_ngn'],0)
        self.assertFalse(ReferralReward.objects.exists())

    def test_change_password_requires_current_password(self):
        from rest_framework.test import APIClient
        api = APIClient()
        api.force_authenticate(user=self.student)
        self.assertEqual(api.post('/api/v1/auth/change-password/', {
            'current_password':'wrong','new_password':'NewStrongPass015#'},format='json').status_code,400)
        self.assertEqual(api.post('/api/v1/auth/change-password/', {
            'current_password':'StrongPass015#','new_password':'NewStrongPass015#'},format='json').status_code,200)
        self.student.refresh_from_db()
        self.assertTrue(self.student.check_password('NewStrongPass015#'))
        self.assertFalse(self.student.check_password('StrongPass015#'))


class OriginalMediaLocalOnly015Tests(TestCase):
    def test_server_rejects_embedded_original_file(self):
        from rest_framework.test import APIClient
        user = StudentUser.objects.create_user(email='localonly015@example.com',password='StrongPass015#', email_verified=True, trial_started_at=timezone.now(),trial_expires_at=timezone.now()+__import__('datetime').timedelta(days=3))
        api = APIClient()
        api.force_authenticate(user=user)
        response = api.post('/api/v1/auth/academic-records/', {'records':[{'kind':'lesson_note','id':'note015','payload':{'id':'note015','updated_at':timezone.now().isoformat(),'image_bytes':'data:image/png;base64,aGVsbG8='}}]},format='json')
        self.assertEqual(response.status_code,400)
