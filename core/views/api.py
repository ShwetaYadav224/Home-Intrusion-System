"""
Core API views — detection, devices, events, known-persons,
security mode, alerts, activity log, and dashboard stats.

All endpoints return a consistent JSON envelope:
    {
        "status": "success" | "error",
        "message": "human-readable description",
        "data": { ... }
    }

Most endpoints require JWT auth and scope data to the user's household.
Device-facing endpoints (detect/*) use AllowAny so ESP32 can call them.
"""

import json
import ipaddress
import logging

import time
from django.conf import settings as django_settings
from django.db.models import Avg, Count, Q, DateTimeField
from django.db.models.functions import TruncDate, TruncMonth, TruncWeek
from django.http import StreamingHttpResponse
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response

from core.models import ActivityLog, Alert, DetectionEvent, Device, DoorEvent, KnownPerson, SecurityMode
from accounts.models import Household
from core.serializers import (
    ActivityLogSerializer,
    AddKnownPersonRequestSerializer,
    AlertSerializer,
    DetectFaceRequestSerializer,
    DetectionEventSerializer,
    DeviceCreateSerializer,
    DeviceSerializer,
    DeviceUpdateSerializer,
    DoorEventSerializer,
    DoorStatusRequestSerializer,
    KnownPersonSerializer,
    SecurityModeSerializer,
    SecurityModeUpdateSerializer,
)
from core.utils.arcface_client import compute_similarity, get_face_embedding
from core.utils.image_processing import compress_image, decode_base64_image, validate_base64
from core.utils.openrouter_client import analyze_image
from core.utils.storage import save_image_bytes

logger = logging.getLogger(__name__)


def _err(msg, code=status.HTTP_400_BAD_REQUEST):
    logger.error("API Error [%d]: %s", code, msg)
    return Response({"status": "error", "message": msg, "data": {}}, status=code)


def _ok(msg, data=None, code=status.HTTP_200_OK):
    return Response({"status": "success", "message": msg, "data": data or {}}, status=code)


def _format_errors(errors):
    parts = []
    for field, msgs in errors.items():
        if isinstance(msgs, list):
            parts.append(f"{field}: {', '.join(str(m) for m in msgs)}")
        else:
            parts.append(f"{field}: {msgs}")
    return "; ".join(parts)


def _get_household(user):
    """Return the user's household or None."""
    return getattr(user, "household", None)


def _log_activity(household, user, action, description, request=None):
    """Write an entry to the activity log."""
    ip = _get_request_ip(request)
    ActivityLog.objects.create(
        household=household,
        user=user,
        action=action,
        description=description,
        ip_address=ip,
    )


def _get_request_ip(request):
    """Extract the caller IP from a Django request."""
    if not request:
        return None

    ip = request.META.get("HTTP_X_FORWARDED_FOR", request.META.get("REMOTE_ADDR"))
    if ip and "," in ip:
        ip = ip.split(",")[0].strip()
    return ip or None


def _sync_camera_stream_url(device, request):
    """
    Keep the device stream URL aligned with the ESP32-CAM's current IP.

    Device requests come from the camera itself, so we can derive the MJPEG
    endpoint from the caller IP and update stale database values automatically.
    """
    if not request or not device or device.device_id == "web-dashboard":
        return

    ip = _get_request_ip(request)
    if not ip:
        return

    try:
        addr = ipaddress.ip_address(ip)
    except ValueError:
        return

    if addr.is_loopback or addr.is_unspecified or not addr.is_private:
        return

    stream_url = f"http://{ip}:81/stream"
    if device.stream_url == stream_url:
        return

    device.stream_url = stream_url
    device.save(update_fields=["stream_url", "updated_at"])


def _create_alert_for_stranger(device, detection, image_file=None, request=None):
    """Auto-create an alert whenever a stranger is detected."""
    household = device.household
    if not household:
        return

    severity = Alert.Severity.MEDIUM
    try:
        sec_mode = household.security_mode
        if sec_mode.mode == SecurityMode.Mode.ARMED:
            severity = Alert.Severity.HIGH
        elif sec_mode.mode == SecurityMode.Mode.HOME:
            severity = Alert.Severity.MEDIUM
        else:
            severity = Alert.Severity.LOW
    except SecurityMode.DoesNotExist:
        severity = Alert.Severity.MEDIUM

    alert = Alert(
        household=household,
        event=detection,
        title=f"Stranger detected at {device.name or device.device_id}",
        message=f"An unrecognized person was detected with {detection.confidence:.0%} confidence.",
        severity=severity,
    )
    if image_file:
        alert.image.save(image_file.name, image_file, save=False)
    alert.save()

    _log_activity(
        household, None,
        ActivityLog.Action.ALERT_CREATED,
        f"Stranger alert: {alert.title}",
        request
    )


@api_view(["GET"])
@permission_classes([AllowAny])
def api_root(request):
    """API root — lists available endpoint groups."""
    return _ok("Home Security API v2", {
        "version": "2.0.0",
        "auth": "/api/v1/auth/",
        "detection": "/api/v1/detect/",
        "devices": "/api/v1/devices/",
        "events": "/api/v1/events/",
        "known_persons": "/api/v1/known-persons/",
        "security_mode": "/api/v1/security-mode/",
        "alerts": "/api/v1/alerts/",
        "activity": "/api/v1/activity/",
        "dashboard": "/api/v1/dashboard/",
    })


@api_view(["GET"])
@permission_classes([AllowAny])
def api_health(request):
    """Lightweight health probe."""
    return _ok("Healthy", {"timestamp": timezone.now().isoformat()})


@api_view(["POST"])
@permission_classes([AllowAny])
def detect_openrouter(request):
    """
    Detect and classify a face using a cloud vision LLM.

    This endpoint is AllowAny so ESP32 devices can call it without JWT.
    The image is saved to Django media storage.
    """
    ser = DetectFaceRequestSerializer(data=request.data)
    if not ser.is_valid():
        return _err(_format_errors(ser.errors))

    data = ser.validated_data
    device_id = data["deviceId"]
    event_type = data["type"]
    image_b64 = data.get("image", "")

    device, created = Device.objects.get_or_create(device_id=device_id)
    if not device.household:
        household = Household.objects.first()
        if household:
            device.household = household
            device.save()
    _sync_camera_stream_url(device, request)

    if not image_b64:
        DetectionEvent.objects.create(
            device=device,
            result=DetectionEvent.Result.UNKNOWN,
            confidence=0.0,
            raw_ai_response=f"Event type: {event_type}, no image provided",
        )
        return _ok(f"Event '{event_type}' logged (no image)", {"result": "unknown", "timestamp": timezone.now().isoformat()})

    is_valid, validation_msg = validate_base64(image_b64)
    if not is_valid:
        return _err(validation_msg)

    try:
        image_bytes = decode_base64_image(image_b64)
        image_file = save_image_bytes(image_bytes)

        detection = DetectionEvent(device=device, result=DetectionEvent.Result.UNKNOWN)
        detection.image.save(image_file.name, image_file, save=True)

        image_url = request.build_absolute_uri(detection.image.url)
        ai_result, raw_response = analyze_image(image_url)

        detection.result = ai_result["result"]
        detection.confidence = ai_result["confidence"]
        detection.raw_ai_response = str(raw_response)
        detection.save()

        if ai_result["result"] == "stranger":
            img_copy = save_image_bytes(image_bytes)
            _create_alert_for_stranger(device, detection, img_copy, request=request)

        _log_activity(
            device.household, None,
            ActivityLog.Action.DETECTION,
            f"OpenRouter: {ai_result['result']} at {device.name or device.device_id}",
            request
        )

        return _ok(f"Person classified as: {ai_result['result']}", {
            "result": ai_result["result"],
            "confidence": ai_result["confidence"],
            "reason": ai_result["reason"],
            "image_url": image_url,
            "timestamp": detection.created_at.isoformat(),
        })

    except Exception as e:
        logger.exception("[DETECT-OR] Unexpected error: %s", e)
        return _err("Internal server error", status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(["POST"])
@permission_classes([AllowAny])
def detect_arcface(request):
    """
    Detect and identify a face via ArcFace embeddings.

    AllowAny so ESP32 devices can call without JWT.
    Compares against KnownPerson records scoped to the device's household.
    """
    ser = DetectFaceRequestSerializer(data=request.data)
    if not ser.is_valid():
        return _err(_format_errors(ser.errors))

    data = ser.validated_data
    image_b64 = data.get("image", "")

    if not image_b64:
        return _err("Missing image")

    is_valid, validation_msg = validate_base64(image_b64)
    if not is_valid:
        return _err(validation_msg)

    try:
        image_bytes = decode_base64_image(image_b64)

        embedding, msg = get_face_embedding(image_bytes)
        if embedding is None:
            return _ok(msg, {"result": "unknown", "embedding": None})

        device_id = data["deviceId"]
        device, created = Device.objects.get_or_create(device_id=device_id)
        if not device.household:
            household = Household.objects.first()
            if household:
                device.household = household
                device.save()
        _sync_camera_stream_url(device, request)

        known_qs = KnownPerson.objects.all().prefetch_related("photos")
        if device.household:
            known_qs = known_qs.filter(household=device.household)

        threshold = django_settings.ARCFACE_SIMILARITY_THRESHOLD
        best_match_name = None
        best_similarity = -1.0

        for person in known_qs:
            if person.embedding:
                try:
                    known_embedding = json.loads(person.embedding)
                    sim = compute_similarity(embedding, known_embedding)
                    if sim > best_similarity:
                        best_similarity = sim
                        best_match_name = person.name
                except Exception as e:
                    logger.error("Error comparing legacy embedding for %s: %s", person.name, e)

            for p_extra in person.photos.all():
                try:
                    extra_embedding = json.loads(p_extra.embedding)
                    sim = compute_similarity(embedding, extra_embedding)
                    if sim > best_similarity:
                        best_similarity = sim
                        best_match_name = person.name
                except Exception as e:
                    logger.error("Error comparing photo embedding for %s (photo %d): %s", person.name, p_extra.id, e)

        if best_match_name and best_similarity > threshold:
            classification = DetectionEvent.Result.FAMILY
            person_name = best_match_name
        else:
            classification = DetectionEvent.Result.STRANGER
            person_name = "Unknown"

        confidence = max(best_similarity, 0.0)

        image_file = save_image_bytes(image_bytes)
        detection = DetectionEvent(
            device=device,
            result=classification,
            confidence=confidence,
            person_name=person_name,
            raw_ai_response=f"ArcFace — match={person_name}, similarity={confidence:.4f}",
        )
        detection.image.save(image_file.name, image_file, save=True)

        image_url = request.build_absolute_uri(detection.image.url) if detection.image else None

        if classification == DetectionEvent.Result.STRANGER:
            img_copy = save_image_bytes(image_bytes)
            _create_alert_for_stranger(device, detection, img_copy, request=request)

        _log_activity(
            device.household, None,
            ActivityLog.Action.DETECTION,
            f"{classification}: {person_name} ({confidence:.0%}) at {device.name or device.device_id}",
            request
        )

        return _ok(f"Person classified as: {person_name}", {
            "result": classification,
            "person_name": person_name,
            "confidence": confidence,
            "detail": msg,
            "image_url": image_url,
            "timestamp": detection.created_at.isoformat(),
        })

    except Exception as e:
        logger.exception("[DETECT-AF] Unexpected error: %s", e)
        return _err("Internal server error", status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(["GET", "POST"])
def known_persons_list(request):
    """
    GET  — List registered family members (household-scoped).
    POST — Register a new family member.
    """
    household = _get_household(request.user)

    if request.method == "GET":
        qs = KnownPerson.objects.all()
        if household:
            qs = qs.filter(household=household)
        ser = KnownPersonSerializer(qs, many=True, context={"request": request})
        return _ok("OK", {"persons": ser.data})

    req_ser = AddKnownPersonRequestSerializer(data=request.data)
    if not req_ser.is_valid():
        return _err(_format_errors(req_ser.errors))

    name = req_ser.validated_data["name"]
    images_b64 = req_ser.validated_data.get("images", [])
    legacy_image_b64 = req_ser.validated_data.get("image")

    to_process = images_b64 if images_b64 else ([legacy_image_b64] if legacy_image_b64 else [])

    if not to_process:
        return _err("No images provided.")

    try:
        person = None
        created_photos = 0

        for idx, img_b64 in enumerate(to_process):
            is_valid, validation_msg = validate_base64(img_b64)
            if not is_valid:
                logger.warning("[ADD_PERSON] Image %d invalid: %s", idx, validation_msg)
                continue

            raw_bytes = decode_base64_image(img_b64)
            image_bytes = compress_image(raw_bytes)
            embedding, msg = get_face_embedding(image_bytes)

            if embedding is None:
                logger.warning("[ADD_PERSON] Could not extract face from image %d: %s", idx, msg)
                continue

            image_file = save_image_bytes(image_bytes)

            if person is None:
                person = KnownPerson.objects.create(
                    household=household,
                    name=name,
                    embedding=json.dumps(list(embedding)),
                )
                person.photo.save(image_file.name, image_file, save=True)
                created_photos += 1
            else:
                from core.models import KnownPersonPhoto
                p_photo = KnownPersonPhoto(
                    person=person,
                    embedding=json.dumps(list(embedding)),
                )
                p_photo.photo.save(image_file.name, image_file, save=True)
                created_photos += 1

        if person is None:
            return _err("Failed to process any valid faces. Please ensure the photos are clear.")

        _log_activity(
            household, request.user,
            ActivityLog.Action.PERSON_ADDED,
            f"Added known person: {name} ({created_photos} photos)",
            request,
        )

        return Response(
            {
                "status": "success",
                "message": f"Registered '{name}' with {created_photos} photos.",
                "data": KnownPersonSerializer(person, context={"request": request}).data,
            },
            status=status.HTTP_201_CREATED,
        )

    except Exception as e:
        logger.exception("[ADD_PERSON] Unexpected error: %s", e)
        return _err("Internal server error", status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(["GET", "POST", "DELETE"])
def known_person_detail(request, pk):
    """
    GET    — Retrieve a single known person.
    DELETE — Remove a known person.
    POST   — Add more photos to an existing person.
    """
    household = _get_household(request.user)
    qs = KnownPerson.objects.all()
    if household:
        qs = qs.filter(household=household)

    try:
        person = qs.get(pk=pk)
    except KnownPerson.DoesNotExist:
        return _err("Person not found", status.HTTP_404_NOT_FOUND)

    if request.method == "GET":
        return _ok("OK", KnownPersonSerializer(person, context={"request": request}).data)

    if request.method == "POST":
        from core.serializers import AddPhotosToPersonSerializer
        req_ser = AddPhotosToPersonSerializer(data=request.data)
        if not req_ser.is_valid():
            return _err(_format_errors(req_ser.errors))

        images_b64 = req_ser.validated_data["images"]
        created_photos = 0

        try:
            from core.models import KnownPersonPhoto
            for idx, img_b64 in enumerate(images_b64):
                is_valid, validation_msg = validate_base64(img_b64)
                if not is_valid:
                    continue

                raw_bytes = decode_base64_image(img_b64)
                image_bytes = compress_image(raw_bytes)
                embedding, msg = get_face_embedding(image_bytes)

                if embedding is None:
                    continue

                image_file = save_image_bytes(image_bytes)
                p_photo = KnownPersonPhoto(
                    person=person,
                    embedding=json.dumps(list(embedding)),
                )
                p_photo.photo.save(image_file.name, image_file, save=True)
                created_photos += 1

            if created_photos == 0:
                return _err("Failed to process any valid faces.")

            _log_activity(
                household, request.user,
                ActivityLog.Action.PERSON_ADDED,
                f"Added {created_photos} photos to member: {person.name}",
                request,
            )

            return Response(
                {
                    "status": "success",
                    "message": f"Added {created_photos} photos to {person.name}",
                    "data": KnownPersonSerializer(person, context={"request": request}).data,
                },
                status=status.HTTP_200_OK,
            )

        except Exception as e:
            logger.exception("[ADD_PHOTOS] Unexpected error: %s", e)
            return _err("Internal server error", status.HTTP_500_INTERNAL_SERVER_ERROR)

    name = person.name
    person.delete()

    _log_activity(
        household, request.user,
        ActivityLog.Action.PERSON_REMOVED,
        f"Removed known person: {name}",
        request,
    )

    return _ok(f"Deleted '{name}'")


@api_view(["DELETE"])
def known_person_photo_delete(request, person_id, photo_id):
    """
    DELETE — Remove a specific photo from a known person.
             If photo_id == "primary", it clears the legacy primary photo.
    """
    household = _get_household(request.user)
    try:
        person = KnownPerson.objects.get(pk=person_id)
        if household and person.household != household:
            return _err("Person not found", status.HTTP_404_NOT_FOUND)
    except KnownPerson.DoesNotExist:
        return _err("Person not found", status.HTTP_404_NOT_FOUND)

    if str(photo_id) == "primary":
        if person.photo:
            person.photo.delete(save=True)
            return _ok("Deleted primary photo")
        return _err("Primary photo not found", status.HTTP_404_NOT_FOUND)

    try:
        photo = person.photos.get(pk=photo_id)
        photo.delete()
        return _ok("Deleted photo")
    except Exception:
        return _err("Photo not found", status.HTTP_404_NOT_FOUND)


@api_view(["GET", "POST"])
def device_list(request):
    """
    GET  — List devices (household-scoped).
    POST — Register a new device for the household.
    """
    household = _get_household(request.user)

    if request.method == "GET":
        qs = Device.objects.all()
        if household:
            qs = qs.filter(household=household)
        return _ok("OK", {"devices": DeviceSerializer(qs, many=True).data})

    ser = DeviceCreateSerializer(data=request.data)
    if not ser.is_valid():
        return _err(_format_errors(ser.errors))

    d = ser.validated_data
    if Device.objects.filter(device_id=d["device_id"]).exists():
        return _err("Device ID already registered.")

    device = Device.objects.create(
        household=household,
        device_id=d["device_id"],
        name=d.get("name", ""),
        location=d.get("location", ""),
        stream_url=d.get("stream_url", ""),
    )

    _log_activity(
        household, request.user,
        ActivityLog.Action.DEVICE_ADDED,
        f"Registered device: {device.device_id}",
        request,
    )

    return Response(
        {"status": "success", "message": "Device registered.", "data": DeviceSerializer(device).data},
        status=status.HTTP_201_CREATED,
    )


@api_view(["GET", "PATCH", "DELETE"])
def device_detail(request, pk):
    """
    GET    — Device detail + recent events.
    PATCH  — Update device name/location/active.
    DELETE — Remove device.
    """
    household = _get_household(request.user)
    qs = Device.objects.all()
    if household:
        qs = qs.filter(household=household)

    try:
        device = qs.get(pk=pk)
    except Device.DoesNotExist:
        return _err("Device not found", status.HTTP_404_NOT_FOUND)

    if request.method == "GET":
        events = device.detections.all()[:20]
        return _ok("OK", {
            "device": DeviceSerializer(device).data,
            "recent_events": DetectionEventSerializer(events, many=True, context={"request": request}).data,
        })

    if request.method == "PATCH":
        ser = DeviceUpdateSerializer(device, data=request.data, partial=True)
        if not ser.is_valid():
            return _err(_format_errors(ser.errors))
        ser.save()
        _log_activity(household, request.user, ActivityLog.Action.DEVICE_UPDATED, f"Updated device: {device.device_id}", request)
        return _ok("Device updated.", DeviceSerializer(device).data)

    did = device.device_id
    device.delete()
    _log_activity(household, request.user, ActivityLog.Action.DEVICE_UPDATED, f"Deleted device: {did}", request)
    return _ok(f"Deleted device '{did}'")


@api_view(["GET"])
def camera_stream(request, pk):
    """
    GET — Return the MJPEG stream URL for a device.
    """
    household = _get_household(request.user)
    qs = Device.objects.all()
    if household:
        qs = qs.filter(household=household)

    try:
        device = qs.get(pk=pk)
    except Device.DoesNotExist:
        return _err("Device not found", status.HTTP_404_NOT_FOUND)

    if not device.stream_url:
        return _err("No stream URL configured for this device")

    return _ok("OK", {"stream_url": device.stream_url})


@api_view(["GET"])
def event_list(request):
    """
    List detection events (household-scoped).

    Query params: ?result=  ?device=  ?limit=  ?date_from=  ?date_to=
    """
    household = _get_household(request.user)
    events = DetectionEvent.objects.select_related("device").all()
    if household:
        events = events.filter(device__household=household)

    result_filter = request.query_params.get("result")
    if result_filter in ("family", "stranger", "unknown"):
        events = events.filter(result=result_filter)

    device_filter = request.query_params.get("device")
    if device_filter:
        events = events.filter(device__device_id=device_filter)

    date_from = request.query_params.get("date_from")
    if date_from:
        events = events.filter(created_at__date__gte=date_from)

    date_to = request.query_params.get("date_to")
    if date_to:
        events = events.filter(created_at__date__lte=date_to)

    try:
        limit = min(int(request.query_params.get("limit", 50)), 200)
    except (ValueError, TypeError):
        limit = 50

    events = events[:limit]
    ser = DetectionEventSerializer(events, many=True, context={"request": request})
    return _ok("OK", {"count": len(ser.data), "events": ser.data})


@api_view(["GET", "DELETE"])
def event_detail(request, pk):
    """
    GET    — Retrieve a single detection event.
    DELETE — Remove a detection event.
    """
    household = _get_household(request.user)
    qs = DetectionEvent.objects.select_related("device").all()
    if household:
        qs = qs.filter(device__household=household)

    try:
        event = qs.get(pk=pk)
    except DetectionEvent.DoesNotExist:
        return _err("Event not found", status.HTTP_404_NOT_FOUND)

    if request.method == "GET":
        return _ok("OK", DetectionEventSerializer(event, context={"request": request}).data)

    event.delete()
    return _ok("Event deleted")


@api_view(["GET", "PUT"])
def security_mode(request):
    """
    GET — Current security mode.
    PUT — Change mode (armed / home / disarmed).
    """
    household = _get_household(request.user)
    if not household:
        return _err("No household associated.", status.HTTP_404_NOT_FOUND)

    mode_obj, _ = SecurityMode.objects.get_or_create(
        household=household,
        defaults={"mode": SecurityMode.Mode.DISARMED},
    )

    if request.method == "GET":
        return _ok("OK", SecurityModeSerializer(mode_obj).data)

    ser = SecurityModeUpdateSerializer(data=request.data)
    if not ser.is_valid():
        return _err(_format_errors(ser.errors))

    old_mode = mode_obj.mode
    mode_obj.mode = ser.validated_data["mode"]
    mode_obj.changed_by = request.user
    mode_obj.save()

    _log_activity(
        household, request.user,
        ActivityLog.Action.MODE_CHANGE,
        f"Security mode: {old_mode} → {mode_obj.mode}",
        request,
    )

    return _ok(f"Security mode set to: {mode_obj.mode}", SecurityModeSerializer(mode_obj).data)


@api_view(["GET"])
def alert_list(request):
    """
    List alerts (household-scoped).

    Query params: ?severity=  ?acknowledged=true|false  ?limit=
    """
    household = _get_household(request.user)
    if not household:
        return _err("No household associated.", status.HTTP_404_NOT_FOUND)

    alerts = Alert.objects.filter(household=household)

    severity = request.query_params.get("severity")
    if severity in ("low", "medium", "high", "critical"):
        alerts = alerts.filter(severity=severity)

    ack = request.query_params.get("acknowledged")
    if ack == "true":
        alerts = alerts.filter(is_acknowledged=True)
    elif ack == "false":
        alerts = alerts.filter(is_acknowledged=False)

    try:
        limit = min(int(request.query_params.get("limit", 50)), 200)
    except (ValueError, TypeError):
        limit = 50

    alerts = alerts[:limit]
    ser = AlertSerializer(alerts, many=True, context={"request": request})
    unack_count = Alert.objects.filter(household=household, is_acknowledged=False).count()
    return _ok("OK", {"count": len(ser.data), "unacknowledged_count": unack_count, "alerts": ser.data})


def _alert_stream_generator(household):
    """Generator that yields unacknowledged alerts as SSE events."""
    last_id = 0
    last_alert = Alert.objects.filter(household=household).order_by("-id").first()
    if last_alert:
        last_id = last_alert.id

    while True:
        new_alerts = Alert.objects.filter(
            household=household,
            id__gt=last_id,
        ).order_by("id")

        for alert in new_alerts:
            last_id = alert.id
            data = {
                "id": alert.id,
                "title": alert.title,
                "message": alert.message,
                "severity": alert.severity,
                "created_at": alert.created_at.isoformat(),
            }
            yield f"data: {json.dumps(data)}\n\n"

        time.sleep(3)


def alert_stream(request):
    """
    SSE endpoint for live alerts (household-scoped).

    Uses a plain Django view (no @api_view) because DRF's content
    negotiation only allows JSONRenderer, which rejects the
    text/event-stream content type with a 406 Not Acceptable.
    JWT authentication is handled manually instead.
    """
    from django.http import JsonResponse
    from rest_framework_simplejwt.authentication import JWTAuthentication
    from rest_framework_simplejwt.tokens import AccessToken

    user = None
    jwt_auth = JWTAuthentication()
    try:
        auth_result = jwt_auth.authenticate(request)
        if auth_result is not None:
            user, _ = auth_result
    except Exception:
        pass

    if user is None:
        token_str = request.GET.get("token")
        if token_str:
            try:
                validated = AccessToken(token_str)
                from django.contrib.auth import get_user_model
                User = get_user_model()
                user = User.objects.get(pk=validated["user_id"])
            except Exception:
                return JsonResponse(
                    {"status": "error", "message": "Invalid or expired token."},
                    status=401,
                )
        else:
            return JsonResponse(
                {"status": "error", "message": "Authentication credentials were not provided."},
                status=401,
            )

    household = _get_household(user)
    if not household:
        return JsonResponse(
            {"status": "error", "message": "No household associated."},
            status=404,
        )

    response = StreamingHttpResponse(
        _alert_stream_generator(household),
        content_type="text/event-stream",
    )
    response["Cache-Control"] = "no-cache"
    response["X-Accel-Buffering"] = "no"
    return response


@api_view(["GET", "POST", "DELETE"])
def alert_detail(request, pk):
    """
    GET    — Retrieve a single alert.
    POST   — Acknowledge the alert.
    DELETE — Delete the alert.
    """
    household = _get_household(request.user)
    if not household:
        return _err("No household associated.", status.HTTP_404_NOT_FOUND)

    try:
        alert = Alert.objects.get(pk=pk, household=household)
    except Alert.DoesNotExist:
        return _err("Alert not found", status.HTTP_404_NOT_FOUND)

    if request.method == "GET":
        return _ok("OK", AlertSerializer(alert, context={"request": request}).data)

    if request.method == "POST":
        if alert.is_acknowledged:
            return _ok("Already acknowledged.", AlertSerializer(alert, context={"request": request}).data)

        alert.is_acknowledged = True
        alert.acknowledged_by = request.user
        alert.acknowledged_at = timezone.now()
        alert.save()

        _log_activity(
            household, request.user,
            ActivityLog.Action.ALERT_ACK,
            f"Acknowledged alert: {alert.title}",
            request,
        )

        return _ok("Alert acknowledged.", AlertSerializer(alert, context={"request": request}).data)

    if request.method == "DELETE":
        alert_title = alert.title
        alert.delete()

        _log_activity(
            household, request.user,
            ActivityLog.Action.ALERT_ACK,
            f"Deleted alert: {alert_title}",
            request,
        )

        return _ok("Alert deleted.")


@api_view(["POST"])
def alert_acknowledge_all(request):
    """Acknowledge all pending alerts for the household."""
    household = _get_household(request.user)
    if not household:
        return _err("No household associated.", status.HTTP_404_NOT_FOUND)

    count = Alert.objects.filter(
        household=household, is_acknowledged=False
    ).update(
        is_acknowledged=True,
        acknowledged_by=request.user,
        acknowledged_at=timezone.now(),
    )

    _log_activity(
        household, request.user,
        ActivityLog.Action.ALERT_ACK,
        f"Bulk acknowledged {count} alerts",
        request,
    )

    return _ok(f"Acknowledged {count} alerts.", {"acknowledged_count": count})


@api_view(["GET"])
def activity_log(request):
    """
    List activity log entries (household-scoped).

    Query params: ?action=  ?limit=
    """
    household = _get_household(request.user)
    if not household:
        return _err("No household associated.", status.HTTP_404_NOT_FOUND)

    logs = ActivityLog.objects.filter(household=household)

    action_filter = request.query_params.get("action")
    if action_filter:
        logs = logs.filter(action=action_filter)

    try:
        limit = min(int(request.query_params.get("limit", 50)), 200)
    except (ValueError, TypeError):
        limit = 50

    logs = logs[:limit]
    ser = ActivityLogSerializer(logs, many=True)
    return _ok("OK", {"count": len(ser.data), "logs": ser.data})


@api_view(["GET"])
def dashboard_stats(request):
    """
    Aggregated dashboard statistics for the mobile/web app.

    Returns counts, recent events, alert summary, and security mode.
    """
    household = _get_household(request.user)

    if not household:
        return _ok("OK", {
            "total_devices": 0, "active_devices": 0,
            "total_events": 0, "events_today": 0,
            "strangers_today": 0, "family_today": 0,
            "known_persons": 0, "total_alerts": 0,
            "unacknowledged_alerts": 0,
            "recent_events": [], "recent_alerts": [],
            "security_mode": {"mode": "disarmed", "changed_by_username": None, "changed_at": None},
        })

    devices = Device.objects.filter(household=household)
    events = DetectionEvent.objects.filter(device__household=household)
    alerts = Alert.objects.filter(household=household)

    today = timezone.now().date()
    events_today = events.filter(created_at__date=today)

    stats = {
        "total_devices": devices.count(),
        "active_devices": devices.filter(is_active=True).count(),
        "total_events": events.count(),
        "events_today": events_today.count(),
        "strangers_today": events_today.filter(result="stranger").count(),
        "family_today": events_today.filter(result="family").count(),
        "known_persons": KnownPerson.objects.filter(household=household).count(),
        "total_alerts": alerts.count(),
        "unacknowledged_alerts": alerts.filter(is_acknowledged=False).count(),
        "recent_events": DetectionEventSerializer(
            events[:10], many=True, context={"request": request}
        ).data,
        "recent_alerts": AlertSerializer(
            alerts.filter(is_acknowledged=False)[:5], many=True, context={"request": request}
        ).data,
    }

    door_events = DoorEvent.objects.filter(device__household=household)
    latest_door = door_events.first()
    stats["door_status"] = latest_door.status if latest_door else "unknown"
    stats["door_last_changed"] = latest_door.created_at.isoformat() if latest_door else None
    stats["door_events_today"] = door_events.filter(created_at__date=today).count()

    try:
        mode_obj = household.security_mode
        stats["security_mode"] = SecurityModeSerializer(mode_obj).data
    except SecurityMode.DoesNotExist:
        stats["security_mode"] = {"mode": "disarmed", "changed_by_username": None, "changed_at": None}

    return _ok("OK", stats)


@api_view(["GET"])
def detection_chart(request):
    """
    Aggregated stranger & unknown detection counts for bar chart.

    Query params: ?period=daily|weekly|monthly
        daily   → last 30 days, grouped by date
        weekly  → last 12 weeks, grouped by ISO week
        monthly → last 12 months, grouped by month
    """
    household = _get_household(request.user)
    if not household:
        return _ok("OK", {
            "period": "daily", "labels": [],
            "stranger_counts": [], "family_counts": [],
            "total_stranger": 0, "total_family": 0,
        })

    period = request.query_params.get("period", "daily")
    now = timezone.now()
    base_qs = DetectionEvent.objects.filter(
        device__household=household,
        result__in=["stranger", "family"],
    )

    if period == "weekly":
        cutoff = now - timezone.timedelta(weeks=12)
        trunc = TruncWeek("created_at", output_field=DateTimeField())
        fmt = "%b %d"
    elif period == "monthly":
        cutoff = now - timezone.timedelta(days=365)
        trunc = TruncMonth("created_at", output_field=DateTimeField())
        fmt = "%b %Y"
    else:
        cutoff = now - timezone.timedelta(days=30)
        trunc = TruncDate("created_at", output_field=DateTimeField())
        fmt = "%b %d"

    base_qs = base_qs.filter(created_at__gte=cutoff)

    stranger_qs = base_qs.filter(result="stranger").annotate(
        bucket=trunc
    ).values("bucket").annotate(count=Count("id")).order_by("bucket")

    family_qs = base_qs.filter(result="family").annotate(
        bucket=trunc
    ).values("bucket").annotate(count=Count("id")).order_by("bucket")

    stranger_map = {r["bucket"]: r["count"] for r in stranger_qs}
    family_map = {r["bucket"]: r["count"] for r in family_qs}
    all_buckets = sorted(set(stranger_map.keys()) | set(family_map.keys()))

    labels = [b.strftime(fmt) for b in all_buckets]
    stranger_counts = [stranger_map.get(b, 0) for b in all_buckets]
    family_counts = [family_map.get(b, 0) for b in all_buckets]

    return _ok("OK", {
        "period": period,
        "labels": labels,
        "stranger_counts": stranger_counts,
        "family_counts": family_counts,
        "total_stranger": sum(stranger_counts),
        "total_family": sum(family_counts),
    })


@api_view(["POST"])
@permission_classes([AllowAny])
def door_status_update(request):
    """
    Receive door open/close status from ESP32 reed switch.

    AllowAny so ESP32 can call without JWT.
    Auto-creates a HIGH alert if door opens while security mode is armed.
    """
    ser = DoorStatusRequestSerializer(data=request.data)
    if not ser.is_valid():
        return _err(_format_errors(ser.errors))

    device_id = ser.validated_data["deviceId"]
    door_status = ser.validated_data["status"]

    device, created = Device.objects.get_or_create(device_id=device_id)
    if not device.household:
        household = Household.objects.first()
        if household:
            device.household = household
            device.save()

    door_event = DoorEvent.objects.create(
        device=device,
        status=door_status,
    )

    action = (
        ActivityLog.Action.DOOR_OPENED
        if door_status == DoorEvent.Status.OPEN
        else ActivityLog.Action.DOOR_CLOSED
    )
    _log_activity(
        device.household, None, action,
        f"Door {door_status} at {device.name or device.device_id}",
        request
    )

    if door_status == DoorEvent.Status.OPEN and device.household:
        try:
            sec_mode = device.household.security_mode
            if sec_mode.mode == SecurityMode.Mode.ARMED:
                Alert.objects.create(
                    household=device.household,
                    title=f"Door opened at {device.name or device.device_id}",
                    message="Door was opened while security is ARMED.",
                    severity=Alert.Severity.HIGH,
                )
                _log_activity(
                    device.household, None,
                    ActivityLog.Action.ALERT_CREATED,
                    f"Door-open alert at {device.name or device.device_id}",
                    request
                )
        except SecurityMode.DoesNotExist:
            pass

    return _ok(f"Door status recorded: {door_status}", {
        "id": door_event.id,
        "device_id": device_id,
        "status": door_status,
        "timestamp": door_event.created_at.isoformat(),
    })


@api_view(["GET"])
def door_events_list(request):
    """
    List door open/close events (household-scoped).

    Query params: ?status=open|closed  ?device=  ?limit=
    """
    household = _get_household(request.user)
    events = DoorEvent.objects.select_related("device").all()
    if household:
        events = events.filter(device__household=household)

    status_filter = request.query_params.get("status")
    if status_filter in ("open", "closed"):
        events = events.filter(status=status_filter)

    device_filter = request.query_params.get("device")
    if device_filter:
        events = events.filter(device__device_id=device_filter)

    try:
        limit = min(int(request.query_params.get("limit", 50)), 200)
    except (ValueError, TypeError):
        limit = 50

    events = events[:limit]
    ser = DoorEventSerializer(events, many=True)
    return _ok("OK", {"count": len(ser.data), "door_events": ser.data})
