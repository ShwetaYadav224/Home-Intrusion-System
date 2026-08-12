"""
OpenRouter vision-LLM client.

Sends an image URL to OpenRouter's chat-completion API and parses the
structured JSON response for family/stranger classification.
"""

import json

import requests
from django.conf import settings

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"

SYSTEM_PROMPT = """\
You are a face recognition classifier for a home security system.
Your job is to analyze the image and determine if the person visible is a known family member or a stranger.

RULES:
- If the image shows a person who appears to be casually present, comfortable, or familiar with the environment, classify as "family".
- If the image shows a person who appears unfamiliar, suspicious, or out of place, classify as "stranger".
- If you cannot determine or there is no clear person in the image, classify as "unknown".

You MUST respond with ONLY valid JSON in this exact format:
{"result": "family" or "stranger" or "unknown", "confidence": 0.0 to 1.0, "reason": "brief explanation"}

Do NOT include any text outside the JSON object."""


def analyze_image(image_url: str) -> tuple[dict, str]:
    """
    Send an image to OpenRouter for classification.

    Args:
        image_url: Public URL of the image to analyze.

    Returns:
        (ai_result_dict, raw_response_string)
    """
    api_key = settings.OPENROUTER_API_KEY
    model = settings.OPENROUTER_MODEL

    if not api_key:
        return _default("OpenRouter API key not configured"), "API key missing"

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": [
                    {
                        "type": "text",
                        "text": "Analyze this image and determine if the person is a known family member or a stranger.",
                    },
                    {"type": "image_url", "image_url": {"url": image_url}},
                ],
            },
        ],
        "max_tokens": 200,
        "temperature": 0.1,
    }

    try:
        response = requests.post(OPENROUTER_URL, headers=headers, json=payload, timeout=30)

        if response.status_code != 200:
            return _default(f"OpenRouter returned status {response.status_code}"), response.text

        data = response.json()
        raw_response = json.dumps(data)
        content = data.get("choices", [{}])[0].get("message", {}).get("content", "")

        return _parse_ai_response(content), raw_response

    except requests.Timeout:
        return _default("AI analysis timed out"), "Request timeout"
    except Exception as e:
        return _default(f"AI analysis failed: {e}"), str(e)


def _default(reason: str) -> dict:
    return {"result": "unknown", "confidence": 0.0, "reason": reason}


def _parse_ai_response(content: str) -> dict:
    """Parse the LLM's JSON response into a structured dict."""
    if not content:
        return _default("Empty AI response")

    try:
        cleaned = content.strip()

        if cleaned.startswith("```"):
            lines = cleaned.split("\n")
            lines = [line for line in lines if not line.strip().startswith("```")]
            cleaned = "\n".join(lines).strip()

        parsed = json.loads(cleaned)

        result = parsed.get("result", "unknown")
        if result not in ("family", "stranger", "unknown"):
            result = "unknown"

        confidence = float(parsed.get("confidence", 0.0))
        confidence = max(0.0, min(1.0, confidence))

        reason = str(parsed.get("reason", "No reason provided"))

        return {"result": result, "confidence": confidence, "reason": reason}

    except (json.JSONDecodeError, ValueError, TypeError):
        lower = content.lower()
        if "family" in lower:
            return {"result": "family", "confidence": 0.5, "reason": "Parsed from unstructured response"}
        if "stranger" in lower:
            return {"result": "stranger", "confidence": 0.5, "reason": "Parsed from unstructured response"}
        return _default("Could not parse AI response")
