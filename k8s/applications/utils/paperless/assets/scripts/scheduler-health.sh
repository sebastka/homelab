#!/bin/sh
set -eux
test $(( $(date +%s) - $(date -r /tmp/celerybeat-schedule +%s) )) -lt 300
