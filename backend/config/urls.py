from django.urls import path, include
from django.contrib import admin
from django.http import JsonResponse

urlpatterns = [
    path("admin/", admin.site.urls),
    path("health/", lambda request: JsonResponse({"status":"ok"})),
    path("api/v1/auth/", include("accounts.urls")),
]
