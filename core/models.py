"""
Core models for the Home Security system.

Models:
    Device          — IoT devices (ESP32 cameras, etc.)
    DetectionEvent  — Face detection events with images stored locally
    KnownPerson     — Registered family members with ArcFace embeddings
    SecurityMode    — Armed / Disarmed / Home mode per household
    Alert           — Security alerts with severity and acknowledgment
    DoorEvent       — Door open/close events from reed switch sensors
    ActivityLog     — Audit trail of all system actions
"""

from django.conf import settings
from django.db import models


class Device(models.Model):
    """An IoT device (e.g. ESP32-CAM) that sends images for face detection."""

    household = models.ForeignKey(
        "accounts.Household",
        on_delete=models.CASCADE,
        related_name="devices",
        null=True,
        blank=True,
    )
    device_id = models.CharField(max_length=100, unique=True, db_index=True)
    name = models.CharField(max_length=150, blank=True, default="")
    location = models.CharField(max_length=200, blank=True, default="", help_text="e.g. Front Door, Backyard")
    stream_url = models.CharField(
        max_length=300, blank=True, default="",
        help_text="MJPEG stream URL, e.g. http://192.168.1.50:81/stream",
    )
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return self.name or self.device_id


class DetectionEvent(models.Model):
    """A single face-detection event captured by a device."""

    class Result(models.TextChoices):
        FAMILY = "family", "Family Member"
        STRANGER = "stranger", "Stranger"
        UNKNOWN = "unknown", "Unknown"

    device = models.ForeignKey(Device, on_delete=models.CASCADE, related_name="detections")
    image = models.ImageField(upload_to="detections/%Y/%m/%d/", blank=True, null=True)
    result = models.CharField(max_length=20, choices=Result.choices, default=Result.UNKNOWN)
    confidence = models.FloatField(default=0.0)
    person_name = models.CharField(max_length=150, blank=True, default="")
    raw_ai_response = models.TextField(blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["result", "-created_at"]),
            models.Index(fields=["device", "-created_at"]),
        ]

    def __str__(self):
        return f"{self.device.device_id} — {self.result} ({self.confidence:.0%}) — {self.created_at:%Y-%m-%d %H:%M}"


class KnownPerson(models.Model):
    """A registered family member with their ArcFace facial embedding."""

    household = models.ForeignKey(
        "accounts.Household",
        on_delete=models.CASCADE,
        related_name="known_persons",
        null=True,
        blank=True,
    )
    name = models.CharField(max_length=150)
    photo = models.ImageField(upload_to="known_persons/", blank=True, null=True)
    embedding = models.TextField(
        blank=True, null=True,
        help_text="JSON-serialized 512-dim ArcFace embedding vector (legacy/primary)"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return self.name


class KnownPersonPhoto(models.Model):
    """Additional photos and embeddings for a known person."""

    person = models.ForeignKey(
        KnownPerson,
        on_delete=models.CASCADE,
        related_name="photos",
    )
    photo = models.ImageField(upload_to="known_persons/extra/")
    embedding = models.TextField(help_text="JSON-serialized 512-dim ArcFace embedding vector")
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Photo for {self.person.name} ({self.id})"


class SecurityMode(models.Model):
    """Current security mode for a household."""

    class Mode(models.TextChoices):
        ARMED = "armed", "Armed (Away)"
        HOME = "home", "Home"
        DISARMED = "disarmed", "Disarmed"

    household = models.OneToOneField(
        "accounts.Household",
        on_delete=models.CASCADE,
        related_name="security_mode",
    )
    mode = models.CharField(max_length=10, choices=Mode.choices, default=Mode.DISARMED)
    changed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
    )
    changed_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.household.name} — {self.mode}"


class Alert(models.Model):
    """A security alert triggered by detection events."""

    class Severity(models.TextChoices):
        LOW = "low", "Low"
        MEDIUM = "medium", "Medium"
        HIGH = "high", "High"
        CRITICAL = "critical", "Critical"

    household = models.ForeignKey(
        "accounts.Household",
        on_delete=models.CASCADE,
        related_name="alerts",
    )
    event = models.ForeignKey(
        DetectionEvent,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="alerts",
    )
    title = models.CharField(max_length=200)
    message = models.TextField(blank=True, default="")
    severity = models.CharField(max_length=10, choices=Severity.choices, default=Severity.MEDIUM)
    image = models.ImageField(upload_to="alerts/%Y/%m/%d/", blank=True, null=True)
    is_acknowledged = models.BooleanField(default=False)
    acknowledged_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="acknowledged_alerts",
    )
    acknowledged_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["severity", "-created_at"]),
            models.Index(fields=["is_acknowledged", "-created_at"]),
        ]

    def __str__(self):
        return f"[{self.severity}] {self.title}"


class DoorEvent(models.Model):
    """Records door open/close events from reed switch sensors."""

    class Status(models.TextChoices):
        OPEN = "open", "Open"
        CLOSED = "closed", "Closed"

    device = models.ForeignKey(
        Device,
        on_delete=models.CASCADE,
        related_name="door_events",
    )
    status = models.CharField(max_length=10, choices=Status.choices)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["device", "-created_at"]),
            models.Index(fields=["status", "-created_at"]),
        ]

    def __str__(self):
        return f"{self.device.device_id} — {self.status} — {self.created_at:%Y-%m-%d %H:%M}"


class ActivityLog(models.Model):
    """Audit trail of actions in the system."""

    class Action(models.TextChoices):
        LOGIN = "login", "User Login"
        LOGOUT = "logout", "User Logout"
        DETECTION = "detection", "Face Detection"
        ALERT_CREATED = "alert_created", "Alert Created"
        ALERT_ACK = "alert_ack", "Alert Acknowledged"
        MODE_CHANGE = "mode_change", "Security Mode Changed"
        PERSON_ADDED = "person_added", "Known Person Added"
        PERSON_REMOVED = "person_removed", "Known Person Removed"
        DEVICE_ADDED = "device_added", "Device Added"
        DEVICE_UPDATED = "device_updated", "Device Updated"
        DOOR_OPENED = "door_opened", "Door Opened"
        DOOR_CLOSED = "door_closed", "Door Closed"
        SETTINGS_CHANGED = "settings_changed", "Settings Changed"

    household = models.ForeignKey(
        "accounts.Household",
        on_delete=models.CASCADE,
        related_name="activity_logs",
        null=True,
        blank=True,
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
    )
    action = models.CharField(max_length=30, choices=Action.choices)
    description = models.TextField(blank=True, default="")
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.action} — {self.description[:50]}"


from django.db.models.signals import post_delete
from django.dispatch import receiver


@receiver(post_delete, sender=DetectionEvent)
def auto_delete_file_on_delete_event(sender, instance, **kwargs):
    """Deletes image from filesystem when DetectionEvent is deleted."""
    if instance.image:
        instance.image.delete(save=False)


@receiver(post_delete, sender=KnownPerson)
def auto_delete_file_on_delete_person(sender, instance, **kwargs):
    """Deletes photo from filesystem when KnownPerson is deleted."""
    if instance.photo:
        instance.photo.delete(save=False)


@receiver(post_delete, sender=KnownPersonPhoto)
def auto_delete_file_on_delete_person_photo(sender, instance, **kwargs):
    """Deletes photo from filesystem when KnownPersonPhoto is deleted."""
    if instance.photo:
        instance.photo.delete(save=False)


@receiver(post_delete, sender=Alert)
def auto_delete_file_on_delete_alert(sender, instance, **kwargs):
    """Deletes image from filesystem when Alert is deleted."""
    if instance.image:
        instance.image.delete(save=False)
