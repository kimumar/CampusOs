from django.urls import path, include
from django.contrib import admin
from django.http import JsonResponse
from accounts import partner_views, views as account_views, student_invite_views, owner_dashboard

urlpatterns = [
    path("admin/", admin.site.urls),
    path("control/", owner_dashboard.dashboard, name="campus_owner_dashboard"),
    path("invite/<str:code>/", student_invite_views.invite_redirect, name="student_invite_redirect"),
    path("reset-password/", account_views.password_reset_page, name="password_reset_page"),
    path("health/", lambda request: JsonResponse({"status":"ok"})),
    path("api/v1/auth/", include("accounts.urls")),
    path("r/<str:code>/", partner_views.referral_redirect, name="referral_redirect"),
    path("partners/login/", partner_views.partner_login, name="partner_login"),
    path("partners/", partner_views.partner_dashboard, name="partner_dashboard"),
    path("partners/logout/", partner_views.partner_logout, name="partner_logout"),
]
