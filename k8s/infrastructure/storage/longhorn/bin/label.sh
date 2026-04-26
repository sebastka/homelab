#!/bin/sh
set -eux

# Groups:
# group1: Nightly incremental backup with 7 day retention
readonly all_groups='group1'

sed 1d volumes.csv | grep -v '^#' | while IFS=, read volume_name pv_name volume_groups; do
    for label in \
        'recurring-job-group.longhorn.io/default=enabled'
    do
        kubectl -n longhorn-system label "volume/${volume_name}" "$label" --overwrite
    done

    echo "$all_groups" | sed 's/ /\n/g' | while read group; do
        if echo "$volume_groups" | sed 's/;/\n/g' | grep -qx "$group"; then
            label="recurring-job-group.longhorn.io/${group}=enabled"
        else
            label="recurring-job-group.longhorn.io/${group}-"
        fi

        kubectl -n longhorn-system label "volume/${volume_name}" "$label" --overwrite
    done
done
