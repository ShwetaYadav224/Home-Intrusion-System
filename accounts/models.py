"""
Account models — Custom User, Household, and UserProfile.

A Household groups users that share one home security system.
Each User belongs to exactly one Household and has a role (owner / member).
"""

from django.contrib.auth.models import AbstractUser
from django.db import models


class Household(models.Model):
    """A physical home with a shared security system."""

    name = models.CharField(max_length=200, help_text="e.g. 'The Sharma Residence'")
    address = models.TextField(blank=True, default="")
    invite_code = models.CharField(
        max_length=20,
        unique=True,
        help_text="Code that new members use to join this household",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.name


class User(AbstractUser):
    """Custom user tied to a Household."""

    class Role(models.TextChoices):
        OWNER = "owner", "Owner"
        MEMBER = "member", "Member"

    household = models.ForeignKey(
        Household,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="members",
    )
    role = models.CharField(max_length=10, choices=Role.choices, default=Role.MEMBER)
    phone = models.CharField(max_length=20, blank=True, default="")
    avatar = models.ImageField(upload_to="avatars/", blank=True, null=True)
    push_token = models.CharField(
        max_length=255,
        blank=True,
        default="",
        help_text="FCM / APNs push notification token from the mobile app",
    )
    password_reset_otp = models.CharField(
        max_length=6,
        blank=True,
        default="",
        help_text="6-digit OTP for password reset",
    )
    otp_created_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-date_joined"]

    def __str__(self):
        return f"{self.get_full_name() or self.username} ({self.role})"
