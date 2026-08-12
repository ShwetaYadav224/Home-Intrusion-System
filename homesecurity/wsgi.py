"""WSGI entrypoint for Home Security Backend."""

import os

from django.core.wsgi import get_wsgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "homesecurity.settings")
application = get_wsgi_application()
