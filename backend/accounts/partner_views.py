"""Small private partner portal, separate from student academic accounts."""
from urllib.parse import urlencode

from django.conf import settings
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.decorators import login_required
from django.db.models import Sum
from django.http import Http404
from django.shortcuts import redirect, render
from django.views.decorators.http import require_GET, require_http_methods

from .models import (ReferralPartner, PartnerReferralCode, ReferralAttribution,
                     ReferralReward, SubscriptionPayment)


@require_GET
def referral_redirect(request, code):
    normalized = code.strip().upper()
    partner = ReferralPartner.objects.filter(code=normalized, active=True).first()
    if not partner:
        alias = PartnerReferralCode.objects.select_related('partner').filter(
            code=normalized, active=True, partner__active=True).first()
        partner = alias.partner if alias else None
    if not partner:
        raise Http404('Referral link is no longer available.')
    # Only a server-owned redirect destination, never a user-supplied URL.
    destination = settings.FRONTEND_URL.rstrip('/') + '/?' + urlencode({'ref': normalized})
    return redirect(destination)


@require_http_methods(['GET', 'POST'])
def partner_login(request):
    if request.method == 'POST':
        email = request.POST.get('email', '').strip().lower()
        password = request.POST.get('password', '')
        user = authenticate(request, email=email, password=password)
        if user and user.is_active and (user.is_superuser or ReferralPartner.objects.filter(
                owner_user=user, active=True).exists()):
            login(request, user)
            return redirect('partner_dashboard')
        return render(request, 'accounts/partner_login.html',
                      {'error': 'Incorrect credentials or inactive partner account.'}, status=403)
    return render(request, 'accounts/partner_login.html')


@login_required(login_url='/partners/login/')
@require_GET
def partner_dashboard(request):
    if request.user.is_superuser:
        partners = ReferralPartner.objects.order_by('university', 'name')
        selected = request.GET.get('partner')
        partner = partners.filter(pk=selected).first() if selected else partners.first()
    else:
        partners = ReferralPartner.objects.filter(owner_user=request.user, active=True)
        partner = partners.first()
    if not partner:
        raise Http404('No partner account available.')
    referral_count = ReferralAttribution.objects.filter(partner=partner).count()
    verified_paid = ReferralReward.objects.filter(partner=partner).count()
    earned = ReferralReward.objects.filter(partner=partner).aggregate(total=Sum('amount_ngn'))['total'] or 0
    paid = ReferralReward.objects.filter(partner=partner, paid_out=True).aggregate(total=Sum('amount_ngn'))['total'] or 0
    base_link = request.build_absolute_uri('/r/')
    codes = [partner.code] + list(partner.extra_codes.filter(active=True).values_list('code', flat=True))
    return render(request, 'accounts/partner_dashboard.html', {
        'partner': partner, 'partners': partners if request.user.is_superuser else None,
        'referral_count': referral_count, 'verified_paid': verified_paid,
        'earned': earned, 'paid': paid, 'pending': earned - paid,
        'links': [(code, base_link + code + '/') for code in codes],
    })


@login_required(login_url='/partners/login/')
@require_http_methods(['POST'])
def partner_logout(request):
    logout(request)
    return redirect('partner_login')
