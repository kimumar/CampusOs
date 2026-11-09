from django.conf import settings
from django.contrib.auth import authenticate
from django.contrib.auth.tokens import default_token_generator
from django.core.exceptions import ValidationError
from django.core.mail import send_mail
from django.db import transaction
from django.utils import timezone
from django.utils.encoding import force_bytes, force_str
from django.utils.http import (
    urlsafe_base64_encode,
    urlsafe_base64_decode,
)
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken

from .models import StudentUser, StudentProfile
from .serializers import RegistrationSerializer, ProfileSerializer


def _uid(user):
    return urlsafe_base64_encode(force_bytes(user.pk))


def _get_user(uid):
    try:
        user_id = force_str(urlsafe_base64_decode(uid))
        return StudentUser.objects.get(pk=user_id)
    except (
        ValueError,
        TypeError,
        OverflowError,
        UnicodeDecodeError,
        StudentUser.DoesNotExist,
    ):
        return None


def _send_token(user, action):
    uid = _uid(user)
    token = default_token_generator.make_token(user)

    url = (
        f"{settings.FRONTEND_URL}/{action}"
        f"?uid={uid}&token={token}"
    )

    send_mail(
        subject=f"CampusOS {action.replace('-', ' ')}",
        message=f"Open this link to continue: {url}",
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[user.email],
        fail_silently=False,
    )


@api_view(["POST"])
@permission_classes([AllowAny])
def register(request):
    serializer = RegistrationSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    with transaction.atomic():
        user = StudentUser.objects.create_user(
            **serializer.validated_data
        )
        StudentProfile.objects.create(user=user)

    _send_token(user, "verify-email")

    return Response(
        {
            "message": (
                "Account created. "
                "Check your email to verify it."
            )
        },
        status=status.HTTP_201_CREATED,
    )


@api_view(["POST"])
@permission_classes([AllowAny])
def verify_email(request):
    user = _get_user(request.data.get("uid", ""))
    token = request.data.get("token", "")

    if not user or not isinstance(token, str) or not token:
        return Response(
            {"detail": "Invalid or expired verification link."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    # Django's default token becomes invalid when certain
    # user fields change. After verification, the token may
    # therefore no longer validate.
    #
    # For an already-verified account, we reconstruct the
    # original pre-verification state in memory and validate
    # the token against that state.
    #
    # No database changes are made during this check.
    if user.email_verified:
        original_verified = user.email_verified
        original_trial_start = user.trial_started_at

        try:
            user.email_verified = False
            user.trial_started_at = None

            valid_token = default_token_generator.check_token(
                user,
                token,
            )
        finally:
            user.email_verified = original_verified
            user.trial_started_at = original_trial_start

        if not valid_token:
            return Response(
                {
                    "detail": (
                        "Invalid or expired verification link."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(
            {"message": "Email already verified."},
            status=status.HTTP_200_OK,
        )

    if not default_token_generator.check_token(user, token):
        return Response(
            {"detail": "Invalid or expired verification link."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    user.email_verified = True
    user.trial_started_at = timezone.now()

    user.save(
        update_fields=[
            "email_verified",
            "trial_started_at",
        ]
    )

    return Response(
        {
            "message": (
                "Email verified. "
                "Your 7-day trial has started."
            )
        },
        status=status.HTTP_200_OK,
    )


@api_view(["POST"])
@permission_classes([AllowAny])
def login(request):
    email = str(
        request.data.get("email", "")
    ).strip().lower()

    password = request.data.get("password", "")

    user = authenticate(
        request,
        email=email,
        password=password,
    )

    if user is None:
        return Response(
            {"detail": "Invalid credentials."},
            status=status.HTTP_401_UNAUTHORIZED,
        )

    if not user.email_verified:
        return Response(
            {
                "detail": (
                    "Verify your email before logging in."
                )
            },
            status=status.HTTP_403_FORBIDDEN,
        )

    refresh = RefreshToken.for_user(user)

    return Response(
        {
            "access": str(refresh.access_token),
            "refresh": str(refresh),
        },
        status=status.HTTP_200_OK,
    )


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def me(request):
    user = request.user

    profile, _ = StudentProfile.objects.get_or_create(
        user=user
    )

    return Response(
        {
            "id": str(user.pk),
            "email": user.email,
            "email_verified": user.email_verified,
            "trial_started_at": user.trial_started_at,
            "trial_ends_at": user.trial_ends_at,
            "paid_until": user.paid_until,
            "academic_access": user.has_academic_access,
            "profile": ProfileSerializer(profile).data,
        },
        status=status.HTTP_200_OK,
    )


@api_view(["GET", "PATCH"])
@permission_classes([IsAuthenticated])
def profile(request):
    obj, _ = StudentProfile.objects.get_or_create(
        user=request.user
    )

    if request.method == "GET":
        return Response(
            ProfileSerializer(obj).data,
            status=status.HTTP_200_OK,
        )

    serializer = ProfileSerializer(
        obj,
        data=request.data,
        partial=True,
    )

    serializer.is_valid(raise_exception=True)
    serializer.save()

    return Response(
        serializer.data,
        status=status.HTTP_200_OK,
    )


@api_view(["POST"])
@permission_classes([AllowAny])
def request_password_reset(request):
    email = str(
        request.data.get("email", "")
    ).strip().lower()

    user = StudentUser.objects.filter(
        email__iexact=email,
        is_active=True,
    ).first()

    if user:
        _send_token(user, "reset-password")

    return Response(
        {
            "message": (
                "If the account exists, "
                "a reset link has been sent."
            )
        },
        status=status.HTTP_200_OK,
    )


@api_view(["POST"])
@permission_classes([AllowAny])
def confirm_password_reset(request):
    user = _get_user(request.data.get("uid", ""))
    token = request.data.get("token", "")
    password = request.data.get("password", "")

    if (
        not user
        or not isinstance(token, str)
        or not default_token_generator.check_token(
            user,
            token,
        )
    ):
        return Response(
            {
                "detail": (
                    "Invalid or expired reset link."
                )
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    from django.contrib.auth.password_validation import (
        validate_password,
    )

    try:
        validate_password(password, user)
    except (ValidationError, TypeError) as exc:
        return Response(
            {"detail": str(exc)},
            status=status.HTTP_400_BAD_REQUEST,
        )

    user.set_password(password)
    user.save(update_fields=["password"])

    return Response(
        {"message": "Password updated."},
        status=status.HTTP_200_OK,
    )