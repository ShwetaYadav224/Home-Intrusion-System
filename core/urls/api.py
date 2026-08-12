"""
API URL routes — mounted at /api/v1/.

Endpoint summary:
    GET     /api/v1/                                → API root
    GET     /api/v1/health/                         → Health probe

    POST    /api/v1/detect/openrouter/              → Detect face (LLM)     [AllowAny]
    POST    /api/v1/detect/arcface/                 → Detect face (ArcFace) [AllowAny]

    GET|POST /api/v1/known-persons/                  → List / add known persons
    GET|DEL  /api/v1/known-persons/<id>/             → Detail / delete known person

    GET|POST /api/v1/devices/                        → List / register devices
    GET|PATCH|DEL /api/v1/devices/<id>/              → Detail / update / delete

    GET     /api/v1/events/                          → List detection events
    GET     /api/v1/events/<id>/                     → Event detail

    GET|PUT /api/v1/security-mode/                   → Get / set security mode
    GET     /api/v1/alerts/                          → List alerts
    GET|POST|DEL /api/v1/alerts/<id>/                → Detail / acknowledge / delete
    POST    /api/v1/alerts/acknowledge-all/          → Acknowledge all

    GET     /api/v1/activity/                        → Activity audit log
    GET     /api/v1/dashboard/                       → Aggregated dashboard stats
"""

from django.urls import path

from core.views.api import (
    activity_log,
    alert_acknowledge_all,
    alert_detail,
    alert_list,
    alert_stream,
    api_health,
    api_root,
    camera_stream,
    dashboard_stats,
    detection_chart,
    detect_arcface,
    detect_openrouter,
    device_detail,
    device_list,
    door_events_list,
    door_status_update,
    event_detail,
    event_list,
    known_person_detail,
    known_person_photo_delete,
    known_persons_list,
    security_mode,
)

app_name = "api"

urlpatterns = [
    path("", api_root, name="root"),
    path("health/", api_health, name="health"),
    path("detect/openrouter/", detect_openrouter, name="detect-openrouter"),
    path("detect/arcface/", detect_arcface, name="detect-arcface"),
    path("known-persons/", known_persons_list, name="known-persons-list"),
    path("known-persons/<int:pk>/", known_person_detail, name="known-person-detail"),
    path("known-persons/<int:person_id>/photos/<str:photo_id>/", known_person_photo_delete, name="known-person-photo-delete"),
    path("devices/", device_list, name="device-list"),
    path("devices/<int:pk>/", device_detail, name="device-detail"),
    path("devices/<int:pk>/stream/", camera_stream, name="camera-stream"),
    path("events/", event_list, name="event-list"),
    path("events/<int:pk>/", event_detail, name="event-detail"),
    path("security-mode/", security_mode, name="security-mode"),
    path("alerts/", alert_list, name="alert-list"),
    path("alerts/stream/", alert_stream, name="alert-stream"),
    path("alerts/acknowledge-all/", alert_acknowledge_all, name="alert-acknowledge-all"),
    path("alerts/<int:pk>/", alert_detail, name="alert-detail"),
    path("activity/", activity_log, name="activity-log"),
    path("dashboard/", dashboard_stats, name="dashboard-stats"),
    path("dashboard/detection-chart/", detection_chart, name="detection-chart"),
    path("door-status/", door_status_update, name="door-status-update"),
    path("door-events/", door_events_list, name="door-events-list"),
]
