"""Custom DRF exception handler for consistent API error responses."""

from rest_framework.views import exception_handler


def custom_exception_handler(exc, context):
    """Wrap all DRF error responses in a uniform envelope."""
    response = exception_handler(exc, context)

    if response is not None:
        response.data = {
            "status": "error",
            "message": _extract_message(response.data),
            "data": {},
        }

    return response


def _extract_message(data):
    """Pull a human-readable message from DRF's error dict/list."""
    if isinstance(data, dict):
        if "detail" in data:
            return str(data["detail"])
        messages = []
        for field, errors in data.items():
            if isinstance(errors, list):
                messages.append(f"{field}: {', '.join(str(e) for e in errors)}")
            else:
                messages.append(f"{field}: {errors}")
        return "; ".join(messages)
    if isinstance(data, list):
        return "; ".join(str(e) for e in data)
    return str(data)
