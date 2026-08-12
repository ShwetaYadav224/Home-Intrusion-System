"""
Local image storage utility.

Saves raw image bytes to Django MEDIA_ROOT via ImageField-compatible
InMemoryUploadedFile objects. Replaces the old Cloudinary upload path.
"""

import io
import uuid

from django.core.files.uploadedfile import InMemoryUploadedFile

from .image_processing import compress_image


def save_image_bytes(image_bytes: bytes, folder: str = "uploads") -> InMemoryUploadedFile:
    """
    Compress and wrap raw image bytes into a Django upload file.

    Args:
        image_bytes: Raw image data (JPEG/PNG).
        folder: Not used for path (ImageField.upload_to handles that),
                kept for API compatibility.

    Returns:
        An InMemoryUploadedFile ready to assign to an ImageField.
    """
    try:
        compressed = compress_image(image_bytes)
    except ValueError:
        compressed = image_bytes

    buf = io.BytesIO(compressed)
    filename = f"{uuid.uuid4().hex}.jpg"

    return InMemoryUploadedFile(
        file=buf,
        field_name="image",
        name=filename,
        content_type="image/jpeg",
        size=len(compressed),
        charset=None,
    )
