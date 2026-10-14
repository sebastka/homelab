#!/bin/sh
set -eux
celery --app paperless inspect ping -d celery@$HOSTNAME --timeout 5
