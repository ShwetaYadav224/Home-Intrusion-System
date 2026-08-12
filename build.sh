#!/usr/bin/env bash
set -o errexit

echo ">>> Installing dependencies with uv..."
uv sync --no-dev

echo ">>> Collecting static files..."
uv run python manage.py collectstatic --no-input

echo ">>> Running migrations..."
uv run python manage.py migrate --no-input

echo ">>> Build complete!"
