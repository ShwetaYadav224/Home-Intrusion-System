"""
Account API views — register, login, logout, profile, household, password.

All endpoints return the consistent envelope:
    {"status": "...", "message": "...", "data": {...}}
"""

import logging
import random
import secrets

from django.contrib.auth import authenticate, get_user_model
from django.db.models import Q
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken

from .models import Household
from .serializers import (
    ChangePasswordSerializer,
    DeleteAccountSerializer,
    ForgotPasswordSerializer,
    HouseholdMemberSerializer,
    HouseholdSerializer,
    HouseholdUpdateSerializer,
    LoginSerializer,
    RegisterSerializer,
    ResetPasswordSerializer,
    UpdatePushTokenSerializer,
    UserSerializer,
    UserUpdateSerializer,
)

User = get_user_model()
logger = logging.getLogger(__name__)


def _tokens_for_user(user):
    refresh = RefreshToken.for_user(user)
    return {
        "access": str(refresh.access_token),
        "refresh": str(refresh),
    }


@api_view(["POST"])
@permission_classes([AllowAny])
def register(request):
    """
    Create a new user account.

    Either create a new household (provide `household_name`) or
    join an existing one (provide `invite_code`).

    Body:
        {
            "username": "john",
            "email": "john@example.com",
            "password": "securepassword",
            "password_confirm": "securepassword",
            "first_name": "John",              // optional
            "last_name": "Doe",                 // optional
            "phone": "+91...",                  // optional
            "household_name": "Doe Residence",  // create new
            "invite_code": "ABC123"             // OR join existing
        }
    """
    ser = RegisterSerializer(data=request.data)
    if not ser.is_valid():
        return Response(
            {"status": "error", "message": _format(ser.errors), "data": {}},
            status=status.HTTP_400_BAD_REQUEST,
        )

    d = ser.validated_data

    if d.get("invite_code"):
        try:
            household = Household.objects.get(invite_code=d["invite_code"])
        except Household.DoesNotExist:
            return Response(
                {"status": "error", "message": "Invalid invite code.", "data": {}},
                status=status.HTTP_400_BAD_REQUEST,
            )
        role = User.Role.MEMBER
    else:
        household = Household.objects.create(
            name=d["household_name"],
            invite_code=secrets.token_urlsafe(12)[:12].upper(),
        )
        role = User.Role.OWNER

    user = User.objects.create_user(
        username=d["username"],
        email=d["email"],
        password=d["password"],
        first_name=d.get("first_name", ""),
        last_name=d.get("last_name", ""),
        phone=d.get("phone", ""),
        household=household,
        role=role,
    )

    logger.info("New user registered: %s (household=%s)", user.username, household.name)

    return Response(
        {
            "status": "success",
            "message": "Account created successfully.",
            "data": {
                "user": UserSerializer(user, context={"request": request}).data,
                "tokens": _tokens_for_user(user),
            },
        },
        status=status.HTTP_201_CREATED,
    )


@api_view(["POST"])
@permission_classes([AllowAny])
def login(request):
    """
    Authenticate and receive JWT tokens.

    Body:
        {"username": "john", "password": "securepassword"}
    """
    ser = LoginSerializer(data=request.data)
    if not ser.is_valid():
        return Response(
            {"status": "error", "message": _format(ser.errors), "data": {}},
            status=status.HTTP_400_BAD_REQUEST,
        )

    identifier = ser.validated_data["identifier"]
    password = ser.validated_data["password"]

    user = authenticate(username=identifier, password=password)
    if user is None:
        try:
            email_user = User.objects.get(email__iexact=identifier)
            user = authenticate(username=email_user.username, password=password)
        except User.DoesNotExist:
            pass

    if user is None:
        return Response(
            {"status": "error", "message": "Invalid username/email or password.", "data": {}},
            status=status.HTTP_401_UNAUTHORIZED,
        )
    if not user.is_active:
        return Response(
            {"status": "error", "message": "Account is disabled.", "data": {}},
            status=status.HTTP_403_FORBIDDEN,
        )

    return Response(
        {
            "status": "success",
            "message": "Login successful.",
            "data": {
                "user": UserSerializer(user, context={"request": request}).data,
                "tokens": _tokens_for_user(user),
            },
        }
    )


@api_view(["POST"])
def logout(request):
    """
    Blacklist the refresh token to log out.

    Body:
        {"refresh": "<refresh-token>"}
    """
    refresh = request.data.get("refresh")
    if not refresh:
        return Response(
            {"status": "error", "message": "Refresh token required.", "data": {}},
            status=status.HTTP_400_BAD_REQUEST,
        )
    try:
        token = RefreshToken(refresh)
        token.blacklist()
    except Exception:
        return Response(
            {"status": "error", "message": "Invalid or expired token.", "data": {}},
            status=status.HTTP_400_BAD_REQUEST,
        )

    return Response({"status": "success", "message": "Logged out.", "data": {}})


@api_view(["POST"])
@permission_classes([AllowAny])
def token_refresh(request):
    """
    Get a new access token using a valid refresh token.

    Body:
        {"refresh": "<refresh-token>"}
    """
    refresh = request.data.get("refresh")
    if not refresh:
        return Response(
            {"status": "error", "message": "Refresh token required.", "data": {}},
            status=status.HTTP_400_BAD_REQUEST,
        )
    try:
        token = RefreshToken(refresh)
        return Response(
            {
                "status": "success",
                "message": "Token refreshed.",
                "data": {
                    "access": str(token.access_token),
                    "refresh": str(token),
                },
            }
        )
    except Exception:
        return Response(
            {"status": "error", "message": "Invalid or expired refresh token.", "data": {}},
            status=status.HTTP_401_UNAUTHORIZED,
        )


@api_view(["GET", "PATCH"])
def profile(request):
    """
    GET  — Return current user profile.
    PATCH — Update first_name, last_name, phone, avatar.
    """
    user = request.user

    if request.method == "GET":
        return Response(
            {
                "status": "success",
                "message": "OK",
                "data": UserSerializer(user, context={"request": request}).data,
            }
        )

    ser = UserUpdateSerializer(user, data=request.data, partial=True)
    if not ser.is_valid():
        return Response(
            {"status": "error", "message": _format(ser.errors), "data": {}},
            status=status.HTTP_400_BAD_REQUEST,
        )
    ser.save()
    return Response(
        {
            "status": "success",
            "message": "Profile updated.",
            "data": UserSerializer(user, context={"request": request}).data,
        }
    )


@api_view(["POST"])
def change_password(request):
    """
    Change the authenticated user's password.

    Body:
        {
            "old_password": "...",
            "new_password": "...",
            "new_password_confirm": "..."
        }
    """
    ser = ChangePasswordSerializer(data=request.data)
    if not ser.is_valid():
        return Response(
            {"status": "error", "message": _format(ser.errors), "data": {}},
            status=status.HTTP_400_BAD_REQUEST,
        )

    user = request.user
    if not user.check_password(ser.validated_data["old_password"]):
        return Response(
            {"status": "error", "message": "Current password is incorrect.", "data": {}},
            status=status.HTTP_400_BAD_REQUEST,
        )

    user.set_password(ser.validated_data["new_password"])
    user.save()

    return Response(
        {
            "status": "success",
            "message": "Password changed. Please log in again.",
            "data": {},
        }
    )


@api_view(["POST"])
def update_push_token(request):
    """
    Save the device push notification token (FCM / APNs).

    Body:
        {"push_token": "fcm-token-here"}
    """
    ser = UpdatePushTokenSerializer(data=request.data)
    if not ser.is_valid():
        return Response(
            {"status": "error", "message": _format(ser.errors), "data": {}},
            status=status.HTTP_400_BAD_REQUEST,
        )
    request.user.push_token = ser.validated_data["push_token"]
    request.user.save(update_fields=["push_token"])
    return Response({"status": "success", "message": "Push token saved.", "data": {}})


@api_view(["GET", "PATCH"])
def household_detail(request):
    """
    GET  — Return user's household details.
    PATCH — Update household name / address (owner only).
    """
    household = request.user.household
    if not household:
        return Response(
            {"status": "error", "message": "No household associated.", "data": {}},
            status=status.HTTP_404_NOT_FOUND,
        )

    if request.method == "GET":
        return Response(
            {
                "status": "success",
                "message": "OK",
                "data": HouseholdSerializer(household).data,
            }
        )

    if request.user.role != User.Role.OWNER:
        return Response(
            {"status": "error", "message": "Only the household owner can update settings.", "data": {}},
            status=status.HTTP_403_FORBIDDEN,
        )

    ser = HouseholdUpdateSerializer(household, data=request.data, partial=True)
    if not ser.is_valid():
        return Response(
            {"status": "error", "message": _format(ser.errors), "data": {}},
            status=status.HTTP_400_BAD_REQUEST,
        )
    ser.save()
    return Response(
        {"status": "success", "message": "Household updated.", "data": HouseholdSerializer(household).data}
    )


@api_view(["GET"])
def household_members(request):
    """List all members of the user's household."""
    household = request.user.household
    if not household:
        return Response(
            {"status": "error", "message": "No household associated.", "data": {}},
            status=status.HTTP_404_NOT_FOUND,
        )

    members = household.members.all()
    return Response(
        {
            "status": "success",
            "message": "OK",
            "data": {
                "members": HouseholdMemberSerializer(members, many=True, context={"request": request}).data,
            },
        }
    )


@api_view(["POST"])
def household_remove_member(request, user_id):
    """Remove a member from the household (owner only)."""
    if request.user.role != User.Role.OWNER:
        return Response(
            {"status": "error", "message": "Only the owner can remove members.", "data": {}},
            status=status.HTTP_403_FORBIDDEN,
        )

    household = request.user.household
    if not household:
        return Response(
            {"status": "error", "message": "No household associated.", "data": {}},
            status=status.HTTP_404_NOT_FOUND,
        )

    if user_id == request.user.id:
        return Response(
            {"status": "error", "message": "Cannot remove yourself.", "data": {}},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        member = User.objects.get(pk=user_id, household=household)
    except User.DoesNotExist:
        return Response(
            {"status": "error", "message": "Member not found in your household.", "data": {}},
            status=status.HTTP_404_NOT_FOUND,
        )

    member.household = None
    member.save(update_fields=["household"])

    return Response(
        {"status": "success", "message": f"Removed {member.username} from household.", "data": {}}
    )

@api_view(["POST"])
@permission_classes([AllowAny])
def forgot_password(request):
    """
    Generate a 6-digit OTP and log it to the console.

    Body:
        {"email": "john@example.com"}

    In production, replace the logger.info with a real email sender.
    """
    ser = ForgotPasswordSerializer(data=request.data)
    if not ser.is_valid():
        return Response(
            {"status": "error", "message": _format(ser.errors), "data": {}},
            status=status.HTTP_400_BAD_REQUEST,
        )

    email = ser.validated_data["email"]
    try:
        user = User.objects.get(email__iexact=email)
    except User.DoesNotExist:
        return Response(
            {"status": "success", "message": "If that email is registered, an OTP has been sent.", "data": {}}
        )

    otp = f"{random.randint(100000, 999999)}"
    user.password_reset_otp = otp
    user.otp_created_at = timezone.now()
    user.save(update_fields=["password_reset_otp", "otp_created_at"])

    logger.info("═══ PASSWORD RESET OTP for %s: %s ═══", email, otp)

    return Response(
        {"status": "success", "message": "If that email is registered, an OTP has been sent.", "data": {}}
    )


@api_view(["POST"])
@permission_classes([AllowAny])
def reset_password(request):
    """
    Verify OTP and set a new password.

    Body:
        {
            "email": "john@example.com",
            "otp": "123456",
            "new_password": "newSecure123",
            "new_password_confirm": "newSecure123"
        }
    """
    ser = ResetPasswordSerializer(data=request.data)
    if not ser.is_valid():
        return Response(
            {"status": "error", "message": _format(ser.errors), "data": {}},
            status=status.HTTP_400_BAD_REQUEST,
        )

    d = ser.validated_data
    try:
        user = User.objects.get(email__iexact=d["email"])
    except User.DoesNotExist:
        return Response(
            {"status": "error", "message": "Invalid email or OTP.", "data": {}},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if not user.password_reset_otp or user.password_reset_otp != d["otp"]:
        return Response(
            {"status": "error", "message": "Invalid or expired OTP.", "data": {}},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if user.otp_created_at and (timezone.now() - user.otp_created_at).total_seconds() > 600:
        user.password_reset_otp = ""
        user.save(update_fields=["password_reset_otp"])
        return Response(
            {"status": "error", "message": "OTP has expired. Please request a new one.", "data": {}},
            status=status.HTTP_400_BAD_REQUEST,
        )

    user.set_password(d["new_password"])
    user.password_reset_otp = ""
    user.otp_created_at = None
    user.save(update_fields=["password", "password_reset_otp", "otp_created_at"])

    logger.info("Password reset successful for %s", user.username)

    return Response(
        {"status": "success", "message": "Password reset successful. You can now log in.", "data": {}}
    )


@api_view(["POST"])
def delete_account(request):
    """
    Permanently delete the authenticated user's account.

    Body:
        {"password": "current-password"}
    """
    ser = DeleteAccountSerializer(data=request.data)
    if not ser.is_valid():
        return Response(
            {"status": "error", "message": _format(ser.errors), "data": {}},
            status=status.HTTP_400_BAD_REQUEST,
        )

    user = request.user
    if not user.check_password(ser.validated_data["password"]):
        return Response(
            {"status": "error", "message": "Incorrect password.", "data": {}},
            status=status.HTTP_400_BAD_REQUEST,
        )

    username = user.username
    user.delete()
    logger.info("Account deleted: %s", username)

    return Response(
        {"status": "success", "message": "Account deleted permanently.", "data": {}}
    )


@api_view(["POST"])
@permission_classes([AllowAny])
def verify_token(request):
    """
    Check if an access token is still valid.

    Body:
        {"token": "<access-token>"}
    """
    from rest_framework_simplejwt.tokens import AccessToken

    token_str = request.data.get("token", "")
    if not token_str:
        return Response(
            {"status": "error", "message": "Token is required.", "data": {}},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        AccessToken(token_str)
        return Response({"status": "success", "message": "Token is valid.", "data": {"valid": True}})
    except Exception:
        return Response(
            {"status": "error", "message": "Token is invalid or expired.", "data": {"valid": False}},
            status=status.HTTP_401_UNAUTHORIZED,
        )


def _format(errors):
    parts = []
    for field, msgs in errors.items():
        if isinstance(msgs, list):
            parts.append(f"{field}: {', '.join(str(m) for m in msgs)}")
        elif isinstance(msgs, dict):
            for k, v in msgs.items():
                parts.append(f"{field}.{k}: {v}")
        else:
            parts.append(f"{field}: {msgs}")
    return "; ".join(parts) if parts else str(errors)
