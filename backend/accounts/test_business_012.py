"""Core subscription, referral and partner privacy regression coverage."""
from datetime import timedelta

from django.test import TestCase
from django.utils import timezone
from django.urls import reverse

from .models import (StudentUser, ReferralPartner, PartnerReferralCode,
                     ReferralAttribution, ReferralReward, SubscriptionPayment,
                     CampusBusinessSettings)
from .subscription_service import verify_recorded_payment


class BusinessControlsTests(TestCase):
    def setUp(self):
        self.settings = CampusBusinessSettings.current()
        self.owner = StudentUser.objects.create_user(
            email='tv@example.com', password='PartnerPassword#123', email_verified=True)
        self.partner = ReferralPartner.objects.create(
            code='UNIJOS', name='UniJos TV', university='UniJos', owner_user=self.owner)
        self.student = StudentUser.objects.create_user(
            email='student@example.com', password='StudentPassword#123', email_verified=True)
        ReferralAttribution.objects.create(user=self.student, partner=self.partner)

    def payment(self, reference, amount=700):
        return SubscriptionPayment.objects.create(
            user=self.student, plan='monthly', amount_ngn=amount,
            external_reference=reference)

    def test_commission_paid_once_and_original_amount_preserved(self):
        self.partner.commission_override_ngn = 350
        self.partner.save(update_fields=['commission_override_ngn'])
        verify_recorded_payment(self.payment('bank-001').pk)
        self.assertEqual(ReferralReward.objects.get(user=self.student).amount_ngn, 350)
        self.partner.commission_override_ngn = 0
        self.partner.save(update_fields=['commission_override_ngn'])
        verify_recorded_payment(self.payment('bank-002').pk)
        self.assertEqual(ReferralReward.objects.filter(user=self.student).count(), 1)
        self.assertEqual(ReferralReward.objects.get(user=self.student).amount_ngn, 350)

    def test_disabled_commission_means_no_new_reward(self):
        self.partner.commissions_enabled = False
        self.partner.save(update_fields=['commissions_enabled'])
        verify_recorded_payment(self.payment('bank-003').pk)
        self.assertFalse(ReferralReward.objects.filter(user=self.student).exists())
        self.partner.commissions_enabled = True
        self.partner.save(update_fields=['commissions_enabled'])
        verify_recorded_payment(self.payment('bank-003-renewal').pk)
        self.assertFalse(ReferralReward.objects.filter(user=self.student).exists())

    def test_complimentary_access_is_free_and_no_commission(self):
        self.student.complimentary_lifetime = True
        self.student.save(update_fields=['complimentary_lifetime'])
        self.assertTrue(self.student.has_academic_access)
        verify_recorded_payment(self.payment('bank-004').pk)
        self.assertFalse(ReferralReward.objects.filter(user=self.student).exists())

    def test_unverified_payment_does_not_unlock_access(self):
        self.payment('bank-005')
        self.assertFalse(self.student.has_academic_access)

    def test_partner_sees_only_own_statistics(self):
        stranger = StudentUser.objects.create_user(
            email='other@example.com', password='OtherPassword#123', email_verified=True)
        other_partner = ReferralPartner.objects.create(
            code='FUTA', name='FUTA TV', university='FUTA', owner_user=stranger)
        ReferralAttribution.objects.create(user=stranger, partner=other_partner)
        self.client.force_login(self.owner)
        response = self.client.get('/partners/?partner=' + str(other_partner.pk))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, 'UNIJOS')
        self.assertNotContains(response, 'FUTA')

    def test_custom_alias_redirect_is_tracked(self):
        PartnerReferralCode.objects.create(code='UNIJOS24', partner=self.partner)
        response = self.client.get('/r/UNIJOS24/')
        self.assertEqual(response.status_code, 302)
        self.assertIn('ref=UNIJOS24', response['Location'])

    def test_price_mismatch_rejected_without_activation(self):
        payment = self.payment('bank-006', 500)
        with self.assertRaises(ValueError):
            verify_recorded_payment(payment.pk)
        payment.refresh_from_db()
        self.assertFalse(payment.verified)
