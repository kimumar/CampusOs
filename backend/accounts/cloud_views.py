from datetime import datetime
from django.db import transaction
from django.utils import timezone
from django.utils.dateparse import parse_datetime
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from .models import AcademicRecord

@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def academic_records(request):
    if request.method == "POST":
        records = request.data.get("records")
        if not isinstance(records, list) or len(records) > 100:
            return Response({"detail": "Supply up to 100 records."}, status=400)
        validated = []
        for item in records:
            if not isinstance(item, dict):
                return Response({"detail": "Invalid record."}, status=400)
            kind = item.get("kind")
            rid = item.get("id")
            payload = item.get("payload")
            if kind not in ("course", "lecture") or not isinstance(rid, str) or not 1 <= len(rid) <= 100 or not isinstance(payload, dict) or len(str(payload)) > 16000:
                return Response({"detail": "Invalid academic record."}, status=400)
            if payload.get("id") != rid:
                return Response({"detail": "Record ID mismatch."}, status=400)
            timestamp = parse_datetime(str(payload.get("updated_at", "")))
            if timestamp is None or timezone.is_naive(timestamp):
                return Response({"detail": "Invalid record timestamp."}, status=400)
            if timestamp > timezone.now() + __import__("datetime").timedelta(minutes=5):
                return Response({"detail": "Future record timestamp."}, status=400)
            validated.append((kind, rid, payload, timestamp))
        with transaction.atomic():
            for kind, rid, payload, timestamp in validated:
                obj, created = AcademicRecord.objects.select_for_update().get_or_create(
                    user=request.user, kind=kind, record_id=rid,
                    defaults={"payload": payload, "modified_at": timestamp, "is_deleted": bool(payload.get("is_deleted"))})
                if not created and timestamp > obj.modified_at:
                    obj.payload = payload
                    obj.modified_at = timestamp
                    obj.is_deleted = bool(payload.get("is_deleted"))
                    obj.save(update_fields=["payload", "modified_at", "is_deleted"])
    result = [{"kind": r.kind, "id": r.record_id, "payload": r.payload}
              for r in AcademicRecord.objects.filter(user=request.user).order_by("kind", "record_id")]
    return Response({"records": result})
