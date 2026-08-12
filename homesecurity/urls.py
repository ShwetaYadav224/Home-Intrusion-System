"""
Home Security Backend — Root URL configuration.

Routes:
    /admin/              → Django admin
    /                    → Health check landing page
    /api/v1/auth/        → Authentication (register, login, logout, profile)
    /api/v1/             → Core API endpoints
    /dashboard/          → Web dashboards
    /media/              → User-uploaded images (dev only)
"""

from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path

from core.views.pages import health_check

urlpatterns = [
    path("admin/", admin.site.urls),
    path("", health_check, name="health-check"),
    path("api/v1/auth/", include("accounts.urls")),
    path("api/v1/", include("core.urls.api")),
    path("dashboard/", include("core.urls.pages")),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
