from django.urls import path
from . import views

urlpatterns = [
    path("academic-progress/", views.upload_progress, name="pulse-progress"),
    path("community-pulse/<str:period>/", views.community_pulse, name="pulse-community"),
]
