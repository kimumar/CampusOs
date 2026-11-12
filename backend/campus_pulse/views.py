"""Authenticated anonymous aggregate progress: no student counts in response."""
from datetime import date, timedelta
from importlib import import_module

from django.conf import settings
from django.db import transaction
from django.http import JsonResponse
from django.utils import timezone
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated

from .models import DailyProgress


def _is_subscribed(user):
    # The host project MUST explicitly configure a checked, server-authoritative
    # subscription eligibility function. Never trust a client-provided flag.
    dotted = getattr(settings, "CAMPUSOS_PULSE_SUBSCRIPTION_CHECK", "")
    if not dotted or "." not in dotted:
        return False
    module, name = dotted.rsplit(".", 1)
    return bool(getattr(import_module(module), name)(user))


def _eligible_users():
    # Host must supply a Django queryset of active subscribed user accounts.
    dotted = getattr(settings, "CAMPUSOS_PULSE_SUBSCRIBERS_QUERYSET", "")
    if not dotted or "." not in dotted:
        return None
    module, name = dotted.rsplit(".", 1)
    return getattr(import_module(module), name)()


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def upload_progress(request):
    if not _is_subscribed(request.user):
        return JsonResponse({"detail": "Active subscription required."}, status=403)
    incoming = request.data.get("days")
    if not isinstance(incoming, list) or len(incoming) > 30:
        return JsonResponse({"detail": "Invalid progress batch."}, status=400)
    today = timezone.localdate()
    validated = []
    for item in incoming:
        if not isinstance(item, dict):
            return JsonResponse({"detail": "Invalid progress item."}, status=400)
        try:
            date_value = date.fromisoformat(item["date"])
            assigned, completed = item["assigned"], item["completed"]
        except (KeyError, TypeError, ValueError):
            return JsonResponse({"detail": "Invalid progress fields."}, status=400)
        if type(assigned) is not int or type(completed) is not int or not (0 <= completed <= assigned <= 3):
            return JsonResponse({"detail": "Invalid completion counts."}, status=400)
        if date_value > today or date_value < today - timedelta(days=35):
            return JsonResponse({"detail": "Date outside sync window."}, status=400)
        validated.append((date_value, assigned, completed))
    with transaction.atomic():
        for study_date, assigned, completed in validated:
            DailyProgress.objects.update_or_create(
                user=request.user, study_date=study_date,
                defaults={"assigned": assigned, "completed": completed},
            )
    return JsonResponse({"accepted": len(validated)})


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def community_pulse(request, period):
    if not _is_subscribed(request.user):
        return JsonResponse({"detail": "Active subscription required."}, status=403)
    subscribers = _eligible_users()
    if subscribers is None:
        return JsonResponse({"detail": "Community aggregation is not yet configured."}, status=503)
    today = timezone.localdate()
    starts = {
        "today": today,
        "week": today - timedelta(days=today.weekday()),
        "month": today.replace(day=1),
    }
    if period not in starts:
        return JsonResponse({"detail": "Unknown period."}, status=404)
    # Denominator includes ALL active subscribed accounts, even those with no
    # missions or no activity. One subscriber contributes at most one fraction.
    eligible_ids = subscribers.values_list("pk", flat=True)
    total_subscribers = subscribers.count()
    if not total_subscribers:
        return JsonResponse({"detail": "No verified community data yet."}, status=503)
    from django.db.models import Sum
    rows = (DailyProgress.objects.filter(user_id__in=eligible_ids,
                                         study_date__gte=starts[period], study_date__lte=today)
            .values("user_id").annotate(assigned_total=Sum("assigned"), completed_total=Sum("completed")))
    thresholds = [0, 0, 0]
    for row in rows:
        assigned = row["assigned_total"] or 0
        completed = row["completed_total"] or 0
        fraction = completed / assigned if assigned else 0.0
        thresholds[0] += fraction >= 1.0
        thresholds[1] += fraction >= 0.9
        thresholds[2] += fraction >= 0.5
    return JsonResponse({
        "period": period,
        "percent_100": round(thresholds[0] * 100 / total_subscribers),
        "percent_90": round(thresholds[1] * 100 / total_subscribers),
        "percent_50": round(thresholds[2] * 100 / total_subscribers),
        "as_of": timezone.now().isoformat(),
    })
