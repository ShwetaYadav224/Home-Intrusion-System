"""Django admin configuration for Home Security models."""

from django.contrib import admin

from .models import ActivityLog, Alert, DetectionEvent, Device, KnownPerson, SecurityMode


@admin.register(Device)
class DeviceAdmin(admin.ModelAdmin):
    list_display = ("device_id", "name", "location", "household", "is_active", "created_at")
    search_fields = ("device_id", "name", "location")
    list_filter = ("is_active", "household")


@admin.register(DetectionEvent)
class DetectionEventAdmin(admin.ModelAdmin):
    list_display = ("device", "result", "person_name", "confidence", "created_at")
    list_filter = ("result", "device")
    search_fields = ("device__device_id", "person_name")
    readonly_fields = ("raw_ai_response",)
    date_hierarchy = "created_at"


@admin.register(KnownPerson)
class KnownPersonAdmin(admin.ModelAdmin):
    list_display = ("name", "household", "photo", "created_at")
    search_fields = ("name",)
    list_filter = ("household",)


@admin.register(SecurityMode)
class SecurityModeAdmin(admin.ModelAdmin):
    list_display = ("household", "mode", "changed_by", "changed_at")
    list_filter = ("mode",)


@admin.register(Alert)
class AlertAdmin(admin.ModelAdmin):
    list_display = ("title", "severity", "household", "is_acknowledged", "created_at")
    list_filter = ("severity", "is_acknowledged", "household")
    search_fields = ("title",)
    date_hierarchy = "created_at"


@admin.register(ActivityLog)
class ActivityLogAdmin(admin.ModelAdmin):
    list_display = ("action", "user", "household", "created_at")
    list_filter = ("action", "household")
    date_hierarchy = "created_at"
    readonly_fields = ("action", "description", "user", "household", "ip_address", "created_at")
