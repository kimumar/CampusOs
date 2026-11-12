from datetime import datetime
from django.db import transaction
from django.utils import timezone
from django.utils.dateparse import parse_datetime
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from .models import AcademicRecord

# User-owned original uploads MUST stay on the phone. Never accept binary
# documents or image/file fields inside the academic-record JSON envelope.
_FORBIDDEN_KEYS = ('image_bytes', 'image_data', 'pdf_bytes', 'pdf_data',
                   'file_bytes', 'file_data', 'attachment', 'attachments',
                   'base64', 'binary', 'file_path', 'image_path', 'pdf_path')

def _contains_file_payload(value):
    if isinstance(value, dict):
        for key, child in value.items():
            normalized = str(key).strip().lower()
            if any(part in normalized for part in _FORBIDDEN_KEYS):
                return True
            if _contains_file_payload(child):
                return True
    elif isinstance(value, list):
        return any(_contains_file_payload(child) for child in value)
    elif isinstance(value, str):
        if value.startswith(('data:image/', 'data:application/pdf;', '%PDF-')):
            return True
    return False


@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def academic_records(request):
    # UI restrictions alone are insufficient: the server must reject direct API
    # reads/writes after a trial or subscription expires. Records remain stored.
    if not request.user.has_academic_access:
        return Response({"detail": "Active academic access required."}, status=403)
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
            # Text-only notes and resumable recall sessions are account-owned,
            # bounded JSON records. Original images and PDFs never sync here.
            max_payload = 65000 if kind in ("lesson_note", "recall_session") else 16000
            if kind not in ("course", "lecture", "lesson_note", "recall_session") or not isinstance(rid, str) or not 1 <= len(rid) <= 100 or not isinstance(payload, dict) or len(str(payload)) > max_payload:
                return Response({"detail": "Invalid academic record."}, status=400)
            if _contains_file_payload(payload):
                return Response({"detail": "Original documents and images stay on your device."}, status=400)
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
