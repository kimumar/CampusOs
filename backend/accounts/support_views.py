from rest_framework.decorators import api_view, permission_classes, throttle_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import UserRateThrottle

from .models import SupportTicket


class SupportRateThrottle(UserRateThrottle):
    scope = "support"


@api_view(["POST"])
@permission_classes([IsAuthenticated])
@throttle_classes([SupportRateThrottle])
def create_ticket(request):
    category = request.data.get("category", "")
    message = request.data.get("message", "")
    if category not in ("bug", "payment", "privacy", "general"):
        return Response({"detail": "Choose a support category."}, status=400)
    if not isinstance(message, str) or not 10 <= len(message.strip()) <= 1500:
        return Response({"detail": "Describe the problem in 10–1500 characters."}, status=400)
    ticket = SupportTicket.objects.create(
        user=request.user, category=category, message=message.strip(),
    )
    return Response({"id": ticket.pk, "message": "Support request received."}, status=201)
