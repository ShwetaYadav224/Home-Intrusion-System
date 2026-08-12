"""
Image processing utilities.

Functions:
    validate_base64   — Check if a string is valid base64 and within size limits.
    decode_base64_image — Decode base64 to raw bytes.
    compress_image     — Resize and compress an image to JPEG.
"""

import base64
import io

from PIL import Image, ImageOps

MAX_BASE64_LENGTH = 10 * 1024 * 1024
MAX_IMAGE_DIMENSION = 800


def validate_base64(base64_string: str) -> tuple[bool, str]:
    """Return (is_valid, message) for a base64-encoded image string."""
    if not base64_string or not isinstance(base64_string, str):
        return False, "Image data is empty or invalid"

    if len(base64_string) > MAX_BASE64_LENGTH:
        return False, f"Image too large (max {MAX_BASE64_LENGTH // (1024 * 1024)} MB)"

    try:
        base64.b64decode(base64_string)
        return True, "Valid"
    except Exception:
        return False, "Invalid base64 encoding"


def decode_base64_image(base64_string: str) -> bytes:
    """Decode a base64 string to raw image bytes."""
    return base64.b64decode(base64_string)


def compress_image(image_bytes: bytes, max_size: int = MAX_IMAGE_DIMENSION, quality: int = 80) -> bytes:
    """
    Resize (if needed) and compress image bytes to JPEG.

    Args:
        image_bytes: Raw image data.
        max_size: Maximum width/height in pixels.
        quality: JPEG quality (1–100).

    Returns:
        Compressed JPEG bytes.

    Raises:
        ValueError: If the image cannot be processed.
    """
    try:
        img = Image.open(io.BytesIO(image_bytes))
        img = ImageOps.exif_transpose(img)

        if img.mode == "RGBA":
            img = img.convert("RGB")

        width, height = img.size
        if width > max_size or height > max_size:
            ratio = min(max_size / width, max_size / height)
            new_size = (int(width * ratio), int(height * ratio))
            img = img.resize(new_size, Image.LANCZOS)

        output = io.BytesIO()
        img.save(output, format="JPEG", quality=quality, optimize=True)
        output.seek(0)
        return output.getvalue()
    except Exception as e:
        raise ValueError(f"Image compression failed: {e}") from e
