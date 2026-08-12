"""Django admin for account models."""

from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.utils.html import format_html

from .models import Household, User


class MemberInline(admin.TabularInline):
    """Inline to show/manage household members directly on the Household page."""

    model = User
    extra = 0
    fields = ("username", "email", "first_name", "last_name", "role", "is_active")
    readonly_fields = ("username", "email")
    show_change_link = True
    verbose_name = "Member"
    verbose_name_plural = "Household Members"


@admin.register(Household)
class HouseholdAdmin(admin.ModelAdmin):
    list_display = ("name", "address_short", "invite_code_display", "member_count", "created_at")
    search_fields = ("name", "invite_code", "address")
    readonly_fields = ("invite_code", "created_at", "updated_at")
    list_per_page = 25
    inlines = [MemberInline]

    fieldsets = (
        (None, {"fields": ("name", "address")}),
        ("Invite Code", {"fields": ("invite_code",), "description": "Share this code with family members to let them join this household."}),
        ("Timestamps", {"fields": ("created_at", "updated_at"), "classes": ("collapse",)}),
    )

    @admin.display(description="Address")
    def address_short(self, obj):
        if obj.address:
            return obj.address[:40] + ("…" if len(obj.address) > 40 else "")
        return "—"

    @admin.display(description="Invite Code")
    def invite_code_display(self, obj):
        return format_html('<code style="padding:2px 6px;background:#f0f0f0;border-radius:3px">{}</code>', obj.invite_code)

    @admin.display(description="Members")
    def member_count(self, obj):
        count = obj.members.count()
        return format_html('<b>{}</b>', count)

    def get_queryset(self, request):
        return super().get_queryset(request).prefetch_related("members")


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = (
        "username", "email", "full_name", "role_badge",
        "household_link", "is_active", "date_joined",
    )
    list_filter = ("role", "is_active", "is_staff", "household")
    search_fields = ("username", "email", "first_name", "last_name", "phone")
    list_per_page = 25
    list_editable = ("is_active",)
    ordering = ("-date_joined",)

    fieldsets = (
        (None, {"fields": ("username", "password")}),
        ("Personal Info", {"fields": ("first_name", "last_name", "email", "phone", "avatar")}),
        ("Household & Role", {"fields": ("household", "role")}),
        ("Permissions", {
            "fields": ("is_active", "is_staff", "is_superuser", "groups", "user_permissions"),
            "classes": ("collapse",),
        }),
        ("Push Notifications", {"fields": ("push_token",), "classes": ("collapse",)}),
        ("Password Reset", {"fields": ("password_reset_otp", "otp_created_at"), "classes": ("collapse",)}),
        ("Important Dates", {"fields": ("last_login", "date_joined", "created_at", "updated_at"), "classes": ("collapse",)}),
    )

    readonly_fields = ("created_at", "updated_at", "otp_created_at", "last_login", "date_joined")

    add_fieldsets = BaseUserAdmin.add_fieldsets + (
        ("Household & Role", {"fields": ("household", "role", "email", "first_name", "last_name")}),
    )

    actions = ["assign_to_household", "remove_from_household", "make_owner", "make_member"]

    @admin.display(description="Name")
    def full_name(self, obj):
        return obj.get_full_name() or "—"

    @admin.display(description="Role")
    def role_badge(self, obj):
        color = "#e74c3c" if obj.role == "owner" else "#3498db"
        return format_html(
            '<span style="padding:2px 8px;border-radius:10px;font-size:11px;color:white;background:{}">{}</span>',
            color, obj.get_role_display(),
        )

    @admin.display(description="Household")
    def household_link(self, obj):
        if obj.household:
            return format_html(
                '<a href="/admin/accounts/household/{}/change/">{}</a>',
                obj.household.pk, obj.household.name,
            )
        return format_html('<span style="color:#999">None</span>')

    @admin.action(description="Assign selected users to a household")
    def assign_to_household(self, request, queryset):
        self.message_user(request, f"Use the edit form to assign {queryset.count()} user(s) to a household.")

    @admin.action(description="Remove selected users from their household")
    def remove_from_household(self, request, queryset):
        updated = queryset.update(household=None)
        self.message_user(request, f"Removed {updated} user(s) from their household.")

    @admin.action(description="Set role to Owner")
    def make_owner(self, request, queryset):
        updated = queryset.update(role="owner")
        self.message_user(request, f"Set {updated} user(s) as Owner.")

    @admin.action(description="Set role to Member")
    def make_member(self, request, queryset):
        updated = queryset.update(role="member")
        self.message_user(request, f"Set {updated} user(s) as Member.")
