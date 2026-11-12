"""Server-only paid access activation. Never call from an untrusted client."""
import calendar
from django.db import transaction
from django.utils import timezone

from .models import SubscriptionPayment, ReferralAttribution, ReferralReward, CampusBusinessSettings


def _add_months(date, months):
    month_zero = date.month - 1 + months
    year = date.year + month_zero // 12
    month = month_zero % 12 + 1
    return date.replace(year=year, month=month,
                        day=min(date.day, calendar.monthrange(year, month)[1]))


@transaction.atomic
def verify_recorded_payment(payment_id):
    """Staff must independently verify bank/provider settlement before calling."""
    payment = SubscriptionPayment.objects.select_for_update().select_related("user").get(pk=payment_id)
    settings = CampusBusinessSettings.current()
    expected = {"monthly": settings.monthly_price_ngn,
                "quarterly": settings.quarterly_price_ngn}.get(payment.plan)
    if expected is None or payment.amount_ngn != expected:
        raise ValueError("Subscription amount does not match the selected plan")
    if payment.verified:
        return payment
    user = payment.user.__class__.objects.select_for_update().get(pk=payment.user_id)
    now = timezone.now()
    start = max(now, user.paid_until) if user.paid_until else now
    user.paid_until = _add_months(start, 1 if payment.plan == "monthly" else 3)
    user.save(update_fields=["paid_until"])
    payment.verified = True
    payment.verified_at = now
    payment.save(update_fields=["verified", "verified_at"])
    attribution = ReferralAttribution.objects.filter(user=user).select_related("partner").first()
    # Complimentary accounts must never generate a paid-conversion referral reward.
    previous_paid = SubscriptionPayment.objects.filter(
        user=user, verified=True).exclude(pk=payment.pk).exists()
    if (attribution and attribution.partner.commissions_enabled
            and not user.has_complimentary_access and not previous_paid):
        partner = attribution.partner
        if payment.plan == "quarterly":
            selected = partner.quarterly_commission_override_ngn
            standard = settings.default_referral_quarterly_commission_ngn
        else:
            selected = partner.monthly_commission_override_ngn
            standard = settings.default_referral_commission_ngn
        if selected is None:
            selected = partner.commission_override_ngn
        commission = selected if selected is not None else standard
        if commission > 0:
            ReferralReward.objects.get_or_create(user=user, defaults={
                "partner": partner, "payment": payment, "amount_ngn": commission,
            })
    return payment
