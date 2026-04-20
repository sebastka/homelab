#!/bin/sh
set -eux

for vol in \
    deluged-config-pv \
    forgejo-shared-storage-pv \
    harbor-joblog-pv harbor-redis-pv harbor-registry-pv harbor-trivy-pv \
    jellyfin-config-pv \
    metube-persistent-pv \
    paperless-data-pv paperless-media-pv \
    portainer-data-pv \
    slink-persist-pv \
    synapse-data-pv \
    thelounge-data-pv
do
    kubectl -n longhorn-system label "volume/${vol}" recurring-job-group.longhorn.io/group1=enabled
    kubectl -n longhorn-system label "volume/${vol}" recurring-job-group.longhorn.io/default-
done
