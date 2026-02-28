#!/bin/sh
set -eux

for vol in \
    longhorn-paperless-data-pv longhorn-paperless-export-pv longhorn-paperless-consume-pv longhorn-paperless-media-pv \
    deluge-config-pv \
    jellyfin-config-pv \
    longhorn-portainer-pv \
    thelounge-data-pv
do
    kubectl -n longhorn-system label "volume/${vol}" recurring-job-group.longhorn.io/group1=enabled
    kubectl -n longhorn-system label "volume/${vol}" recurring-job-group.longhorn.io/default-
done
