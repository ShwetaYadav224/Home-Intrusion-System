"""Page views — HTML dashboards and health check."""

from django.http import HttpResponse
from django.shortcuts import render
from django.views.decorators.http import require_GET


@require_GET
def health_check(request):
    """Landing page confirming the server is running."""
    return render(request, "home.html")


@require_GET
def security_dashboard(request):
    """Main professional security management dashboard."""
    return render(request, "dashboard.html")


@require_GET
def arcface_dashboard(request):
    """ArcFace endpoint tester UI."""
    return render(request, "arcface_dashboard.html")


@require_GET
def manage_family(request):
    """Family member management UI."""
    return render(request, "manage_family.html")
