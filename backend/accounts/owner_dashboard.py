"""Private, low-query business overview. Django Admin remains the editing system."""
from django.contrib.admin.views.decorators import staff_member_required
from django.db.models import Sum
from django.utils import timezone
from django.http import HttpResponseForbidden
from django.shortcuts import render
from .models import (StudentUser, CampusBusinessSettings, ReferralPartner,
                     SubscriptionPayment, ReferralReward, SupportTicket)

@staff_member_required(login_url='/admin/login/')
def dashboard(request):
    if not request.user.is_superuser:
        return HttpResponseForbidden('Only the CampusOS owner can see this dashboard.')
    config = CampusBusinessSettings.current()
    students = StudentUser.objects.filter(is_staff=False)
    payments = SubscriptionPayment.objects.filter(verified=True)
    return render(request, 'accounts/owner_dashboard.html', {
        'settings': config,
        'student_count': students.count(),
        'active_paid_count': students.filter(paid_until__gt=timezone.now()).count(),
        'verified_revenue': payments.aggregate(v=Sum('amount_ngn'))['v'] or 0,
        'partner_count': ReferralPartner.objects.count(),
        'rewards_owed': ReferralReward.objects.filter(paid_out=False).aggregate(v=Sum('amount_ngn'))['v'] or 0,
        'support_open': SupportTicket.objects.filter(is_resolved=False).count(),
    })
