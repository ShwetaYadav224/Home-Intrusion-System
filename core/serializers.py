"""DRF Serializers for the Home Security API."""

from rest_framework import serializers

from .models import ActivityLog, Alert, DetectionEvent, Device, DoorEvent, KnownPerson, SecurityMode


class DeviceSerializer(serializers.ModelSerializer):
    class Meta:
        model = Device
        fields = ["id", "device_id", "name", "location", "stream_url", "is_active", "created_at", "updated_at"]
        read_only_fields = ["id", "created_at", "updated_at"]


class DeviceCreateSerializer(serializers.Serializer):
    device_id = serializers.CharField(max_length=100)
    name = serializers.CharField(max_length=150, required=False, default="")
    location = serializers.CharField(max_length=200, required=False, default="")
    stream_url = serializers.CharField(max_length=300, required=False, default="")


class DeviceUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Device
        fields = ["name", "location", "stream_url", "is_active"]


class DetectionEventSerializer(serializers.ModelSerializer):
    device_id = serializers.CharField(source="device.device_id", read_only=True)
    device_name = serializers.CharField(source="device.name", read_only=True)
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = DetectionEvent
        fields = [
            "id", "device_id", "device_name", "image_url",
            "result", "confidence", "person_name", "created_at",
        ]
        read_only_fields = ["id", "created_at"]

    def get_image_url(self, obj):
        if obj.image:
            request = self.context.get("request")
            if request:
                return request.build_absolute_uri(obj.image.url)
            return obj.image.url
        return None


class KnownPersonSerializer(serializers.ModelSerializer):
    photo_urls = serializers.SerializerMethodField()

    class Meta:
        model = KnownPerson
        fields = ["id", "name", "photo_urls", "photos", "created_at", "updated_at"]
        read_only_fields = ["id", "created_at", "updated_at"]

    photos = serializers.SerializerMethodField()

    def get_photo_urls(self, obj):
        urls = []
        request = self.context.get("request")

        if obj.photo:
            url = request.build_absolute_uri(obj.photo.url) if request else obj.photo.url
            urls.append(url)

        for p in obj.photos.all():
            if p.photo:
                url = request.build_absolute_uri(p.photo.url) if request else p.photo.url
                urls.append(url)
        return urls

    def get_photos(self, obj):
        photos_list = []
        request = self.context.get("request")

        if obj.photo:
            url = request.build_absolute_uri(obj.photo.url) if request else obj.photo.url
            photos_list.append({"id": "primary", "url": url})

        for p in obj.photos.all():
            if p.photo:
                url = request.build_absolute_uri(p.photo.url) if request else p.photo.url
                photos_list.append({"id": str(p.id), "url": url})
        return photos_list


class SecurityModeSerializer(serializers.ModelSerializer):
    changed_by_username = serializers.CharField(source="changed_by.username", read_only=True, default=None)

    class Meta:
        model = SecurityMode
        fields = ["mode", "changed_by_username", "changed_at"]


class SecurityModeUpdateSerializer(serializers.Serializer):
    mode = serializers.ChoiceField(choices=SecurityMode.Mode.choices)


class AlertSerializer(serializers.ModelSerializer):
    event_id = serializers.IntegerField(source="event.id", read_only=True, default=None)
    acknowledged_by_username = serializers.CharField(
        source="acknowledged_by.username", read_only=True, default=None
    )
    image_url = serializers.SerializerMethodField()

    class Meta:
        model = Alert
        fields = [
            "id", "title", "message", "severity", "image_url",
            "event_id", "is_acknowledged", "acknowledged_by_username",
            "acknowledged_at", "created_at",
        ]
        read_only_fields = ["id", "created_at"]

    def get_image_url(self, obj):
        if obj.image:
            request = self.context.get("request")
            if request:
                return request.build_absolute_uri(obj.image.url)
            return obj.image.url
        return None


class ActivityLogSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source="user.username", read_only=True, default=None)

    class Meta:
        model = ActivityLog
        fields = ["id", "action", "description", "username", "ip_address", "created_at"]
        read_only_fields = ["id", "created_at"]


class DetectFaceRequestSerializer(serializers.Serializer):
    """Validates the incoming face-detection request payload."""

    deviceId = serializers.CharField(max_length=100, help_text="Unique device identifier")
    type = serializers.CharField(max_length=50, help_text="Event type (e.g. motion, manual-test)")
    image = serializers.CharField(
        required=False,
        allow_blank=True,
        help_text="Base64-encoded image (JPEG/PNG). Optional for event-only logging.",
    )


class AddKnownPersonRequestSerializer(serializers.Serializer):
    """Validates the payload for registering a new family member."""

    name = serializers.CharField(max_length=150, help_text="Person's display name")
    images = serializers.ListField(
        child=serializers.CharField(),
        required=False,
        help_text="List of Base64-encoded face images"
    )
    image = serializers.CharField(required=False, help_text="Single base64 image (deprecated)")
class AddPhotosToPersonSerializer(serializers.Serializer):
    """Validates the payload for adding photos to an existing member."""

    images = serializers.ListField(
        child=serializers.CharField(),
        required=True,
        help_text="List of Base64-encoded face images"
    )


class DoorEventSerializer(serializers.ModelSerializer):
    device_id = serializers.CharField(source="device.device_id", read_only=True)
    device_name = serializers.CharField(source="device.name", read_only=True)

    class Meta:
        model = DoorEvent
        fields = ["id", "device_id", "device_name", "status", "created_at"]
        read_only_fields = ["id", "created_at"]


class DoorStatusRequestSerializer(serializers.Serializer):
    """Validates incoming door status from ESP32 reed switch."""

    deviceId = serializers.CharField(max_length=100, help_text="Unique device identifier")
    status = serializers.ChoiceField(
        choices=DoorEvent.Status.choices,
        help_text="Door status: open or closed",
    )
