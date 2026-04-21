#!/bin/sh
set -eux

# Group1: Nightly full backup with 7 day retention
for vol in \
    deluged-config-pv \
    paperless-data-pv paperless-media-pv \
    synapse-data-pv
do
    for label in \
        'recurring-job-group.longhorn.io/default-' \
        'recurring-job-group.longhorn.io/group1=enabled' \
        'recurring-job-group.longhorn.io/group2-' \
        'backup-target-' \
        'backup-target=nfs-backup-target'
    do
        kubectl -n longhorn-system label "volume/${vol}" "$label"
    done
done

# Group2: Nightly incremental backup with 7 day retention
for vol in \
    jellyfin-config-pv \
    forgejo-shared-storage-pv \
    harbor-joblog-pv harbor-redis-pv harbor-registry-pv harbor-trivy-pv \
    metube-persistent-pv \
    portainer-data-pv \
    slink-app-pv \
    thelounge-data-pv
do
    for label in \
        'recurring-job-group.longhorn.io/default-' \
        'recurring-job-group.longhorn.io/group1-' \
        'recurring-job-group.longhorn.io/group2=enabled' \
        'backup-target-' \
        'backup-target=nfs-backup-target'
    do
        kubectl -n longhorn-system label "volume/${vol}" "$label"
    done
done
