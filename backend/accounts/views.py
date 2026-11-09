from django.conf import settings
from django.contrib.auth import authenticate
from django.contrib.auth.tokens import default_token_generator
from .tokens import email_verification_token
from django.core.mail import send_mail
from django.db import transaction
from django.utils import timezone
from django.utils.encoding import force_str
from django.utils.http import urlsafe_base64_encode, urlsafe_base64_decode
from django.utils.encoding import force_bytes
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes, throttle_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import AnonRateThrottle
from rest_framework_simplejwt.tokens import RefreshToken
from .models import StudentUser, StudentProfile
from .verification import issue, check
from .brevo_mail import send_code
from .serializers import RegistrationSerializer, ProfileSerializer

def _uid(user):
    return urlsafe_base64_encode(force_bytes(user.pk))

def _get_user(uid):
    try:
        return StudentUser.objects.get(pk=force_str(urlsafe_base64_decode(uid)))
    except (ValueError, TypeError, OverflowError, StudentUser.DoesNotExist):
        return None

def _send_token(user, action):
    uid = _uid(user)
    token = (email_verification_token if action == "verify-email" else default_token_generator).make_token(user)
    url = f"{settings.FRONTEND_URL}/{action}?uid={uid}&token={token}"
    send_mail(f"CampusOS {action.replace('-', ' ')}", f"Open this link to continue: {url}",
              settings.DEFAULT_FROM_EMAIL, [user.email], fail_silently=False)

@api_view(["POST"])
@permission_classes([AllowAny])
def register(request):
    serializer = RegistrationSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    with transaction.atomic():
        user = StudentUser.objects.create_user(**serializer.validated_data)
        StudentProfile.objects.create(user=user)
    code = issue(user)
    try:
        send_code(user.email, code)
    except Exception:
        # Keep the account so the user can retry, but do not pretend delivery succeeded.
        return Response({"detail":"Account created, but verification email delivery failed. Please retry shortly."}, status=503)
    return Response({"message":"We sent a 6-digit code to your email.", "email":user.email}, status=status.HTTP_201_CREATED)

@api_view(["POST"])
@permission_classes([AllowAny])
def verify_email(request):
    user = _get_user(request.data.get("uid", ""))
    token = request.data.get("token", "")
    if not user or user.email_verified or not email_verification_token.check_token(user, token):
        return Response({"detail":"Invalid or expired verification link."}, status=400)
    if not user.email_verified:
        user.email_verified = True
        user.trial_started_at = timezone.now()
        user.save(update_fields=["email_verified","trial_started_at"])
    return Response({"message":"Email verified. Your 7-day trial has started."})

@api_view(["POST"])
@permission_classes([AllowAny])
def login(request):
    email = str(request.data.get("email", "")).strip().lower()
    password = request.data.get("password", "")
    user = authenticate(request, email=email, password=password)
    if user is None:
        return Response({"detail":"Invalid credentials."}, status=401)
    if not user.email_verified:
        return Response({"detail":"Verify your email before logging in."}, status=403)
    refresh = RefreshToken.for_user(user)
    return Response({"access":str(refresh.access_token),"refresh":str(refresh)})

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def me(request):
    user = request.user
    profile, _ = StudentProfile.objects.get_or_create(user=user)
    return Response({
        "id":str(user.pk), "email":user.email, "email_verified":user.email_verified,
        "trial_started_at":user.trial_started_at, "trial_ends_at":user.trial_ends_at,
        "paid_until":user.paid_until, "academic_access":user.has_academic_access,
        "profile":ProfileSerializer(profile).data,
    })

@api_view(["GET","PATCH"])
@permission_classes([IsAuthenticated])
def profile(request):
    obj, _ = StudentProfile.objects.get_or_create(user=request.user)
    if request.method == "GET":
        return Response(ProfileSerializer(obj).data)
    serializer = ProfileSerializer(obj, data=request.data, partial=True)
    serializer.is_valid(raise_exception=True)
    serializer.save()
    return Response(serializer.data)

@api_view(["POST"])
@permission_classes([AllowAny])
def request_password_reset(request):
    email = str(request.data.get("email", "")).strip().lower()
    user = StudentUser.objects.filter(email__iexact=email, is_active=True).first()
    if user:
        _send_token(user, "reset-password")
    return Response({"message":"If the account exists, a reset link has been sent."})

@api_view(["POST"])
@permission_classes([AllowAny])
def confirm_password_reset(request):
    user = _get_user(request.data.get("uid", ""))
    token = request.data.get("token", "")
    password = request.data.get("password", "")
    if not user or not default_token_generator.check_token(user, token):
        return Response({"detail":"Invalid or expired reset link."}, status=400)
    from django.contrib.auth.password_validation import validate_password
    from django.core.exceptions import ValidationError
    try:
        validate_password(password, user)
    except (ValidationError, TypeError) as exc:
        return Response({"detail":str(exc)}, status=400)
    user.set_password(password)
    user.save(update_fields=["password"])
    return Response({"message":"Password updated."})

@api_view(["POST"])
@permission_classes([AllowAny])
@throttle_classes([AnonRateThrottle])
def resend_verification(request):
    email = str(request.data.get("email", "")).strip().lower()
    user = StudentUser.objects.filter(email__iexact=email, email_verified=False, is_active=True).first()
    if user:
        code = issue(user)
        if code is not None:
            try:
                send_code(user.email, code)
            except Exception:
                return Response({"detail":"Email delivery failed. Please try again later."},status=503)
    return Response({"message":"If verification is pending, a code has been sent. Please wait 60 seconds before resending."})


@api_view(["POST"])
@permission_classes([AllowAny])
@throttle_classes([AnonRateThrottle])
def verify_code(request):
    email = str(request.data.get("email", "")).strip().lower()
    code = str(request.data.get("code", "")).strip()
    if len(code) != 6 or not code.isascii() or not code.isdecimal():
        return Response({"detail":"Enter a valid six-digit code."},status=400)
    user = StudentUser.objects.filter(email__iexact=email, is_active=True).first()
    if not user or user.email_verified or not check(user, code):
        return Response({"detail":"Incorrect or expired code. Request a new code if needed."},status=400)
    user.email_verified = True
    if user.trial_started_at is None:
        user.trial_started_at = timezone.now()
    user.save(update_fields=["email_verified","trial_started_at"])
    return Response({"message":"Email verified. Your 7-day trial has started."})
