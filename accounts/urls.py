"""
Auth URL routes — mounted at /api/v1/auth/.

Endpoint summary:
    POST /api/v1/auth/register/             → Create account + household
    POST /api/v1/auth/login/                → Get JWT tokens (username or email)
    POST /api/v1/auth/logout/               → Blacklist refresh token
    POST /api/v1/auth/token/refresh/        → Refresh access token
    GET|PATCH /api/v1/auth/profile/          → View / update profile
    POST /api/v1/auth/change-password/      → Change password
    POST /api/v1/auth/forgot-password/      → Request password reset OTP
    POST /api/v1/auth/reset-password/       → Verify OTP + reset password
    POST /api/v1/auth/delete-account/       → Permanently delete account
    POST /api/v1/auth/verify-token/         → Check if access token is valid
    POST /api/v1/auth/push-token/           → Save FCM/APNs push token
    GET|PATCH /api/v1/auth/household/        → Household details
    GET  /api/v1/auth/household/members/     → List household members
    POST /api/v1/auth/household/members/<id>/remove/ → Remove member (owner)
"""

from django.urls import path

from . import views

app_name = "accounts"

urlpatterns = [
    path("register/", views.register, name="register"),
    path("login/", views.login, name="login"),
    path("logout/", views.logout, name="logout"),
    path("token/refresh/", views.token_refresh, name="token-refresh"),
    path("profile/", views.profile, name="profile"),
    path("change-password/", views.change_password, name="change-password"),
    path("forgot-password/", views.forgot_password, name="forgot-password"),
    path("reset-password/", views.reset_password, name="reset-password"),
    path("delete-account/", views.delete_account, name="delete-account"),
    path("verify-token/", views.verify_token, name="verify-token"),
    path("push-token/", views.update_push_token, name="push-token"),
    path("household/", views.household_detail, name="household"),
    path("household/members/", views.household_members, name="household-members"),
    path("household/members/<int:user_id>/remove/", views.household_remove_member, name="household-remove-member"),
]
