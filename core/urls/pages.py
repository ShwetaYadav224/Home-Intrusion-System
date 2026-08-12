"""Dashboard page routes — mounted at /dashboard/."""

from django.urls import path

from core.views.pages import arcface_dashboard, manage_family, security_dashboard

app_name = "dashboard"

urlpatterns = [
    path("", security_dashboard, name="home"),
    path("arcface/", arcface_dashboard, name="arcface"),
    path("family/", manage_family, name="family"),
]
