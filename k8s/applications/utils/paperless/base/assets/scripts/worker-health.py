#!/opt/paperless/bin/python
"""The worker's probe: pings this pod's Celery worker (celery@<hostname>), as `celery inspect ping`.
Python, since the image has no shell."""

import os
import socket

os.execvp('celery', ['celery', '--app', 'paperless', 'inspect', 'ping',
                     '-d', f'celery@{socket.gethostname()}', '--timeout', '5'])
