# ─────────────────────────────────────────────────────────
#  Home Security Backend — Production Dockerfile (Render)
# ─────────────────────────────────────────────────────────
#  Multi-stage build:
#    Stage 1 → install deps with uv (builder)
#    Stage 2 → slim runtime image
# ─────────────────────────────────────────────────────────

# ── Stage 1: Builder ──────────────────────────────────────
FROM python:3.11-slim AS builder

# System deps needed to compile psycopg2, opencv, insightface, etc.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Install uv (fast Python package manager)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

WORKDIR /app

# Copy dependency manifests first (better layer caching)
COPY pyproject.toml uv.lock ./

# Install production dependencies into a virtual env
RUN uv sync --frozen --no-dev

# Copy the rest of the application code
COPY . .

# Collect Django static files at build time
RUN uv run python manage.py collectstatic --no-input


# ── Stage 2: Runtime ─────────────────────────────────────
FROM python:3.11-slim AS runtime

# Runtime system libraries (opencv, postgres client, etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Non-root user for security
RUN groupadd -r app && useradd -r -g app -d /app -s /sbin/nologin app

WORKDIR /app

# Copy the full app + virtual env from builder
COPY --from=builder --chown=app:app /app /app

# Create writable dirs for insightface model cache and matplotlib config
RUN mkdir -p /app/.insightface /app/.config/matplotlib && \
    chown -R app:app /app/.insightface /app/.config

# Put the venv's bin on PATH so gunicorn/python are found
ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    HOME=/app \
    MPLCONFIGDIR=/app/.config/matplotlib

USER app

# Render injects $PORT at runtime (default 8000 for local testing)
EXPOSE 8000

# Run migrations, create superuser if env vars set, then start gunicorn
CMD sh -c "\
    python manage.py migrate --no-input && \
    if [ -n \"$DJANGO_SUPERUSER_USERNAME\" ]; then \
    python manage.py createsuperuser --no-input 2>/dev/null || true; \
    fi && \
    gunicorn homesecurity.wsgi:application \
    --bind 0.0.0.0:${PORT:-8000} \
    --workers 2 \
    --timeout 120 \
    --access-logfile - \
    --error-logfile -"
