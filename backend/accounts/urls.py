from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from . import views, cloud_views, support_views
from campus_pulse import views as pulse_views
urlpatterns = [
    path("academic-records/", cloud_views.academic_records),
    path("academic-progress/", pulse_views.upload_progress),
    path("community-pulse/<str:period>/", pulse_views.community_pulse),
    path("support-tickets/", support_views.create_ticket),
    path("register/", views.register),
    path("verify-email/", views.verify_email),
    path("verify-code/", views.verify_code),
    path("resend-verification/", views.resend_verification),
    path("login/", views.login),
    path("refresh/", TokenRefreshView.as_view()),
    path("me/", views.me),
    path("profile/", views.profile),
    path("my-invitation/", views.my_invitation),
    path("change-password/", views.change_password),
    path("password-reset/", views.request_password_reset),
    path("password-reset/confirm/", views.confirm_password_reset),
]
