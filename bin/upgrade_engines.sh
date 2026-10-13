#!/bin/sh
set -eu

# ./bin/upgrade_engines.sh
#
# Moves every Longhorn volume to the default engine image (the `default-engine-image` setting,
# i.e. the engine shipped with the installed Longhorn), one volume at a time, waiting for each to
# finish and be healthy again before starting the next.
#
# Attached volumes are upgraded live: Longhorn swaps the engine under the running workload, so
# nothing restarts. A live upgrade is only started on a healthy volume, since swapping the engine
# of a degraded or rebuilding one risks its data. Detached volumes are upgraded offline, which only
# changes the image they will start with.
#
# Automatic engine upgrades stay off (`concurrent-automatic-engine-upgrade-per-node-limit` is 0),
# so this is run by hand after each Longhorn upgrade. Uses the current kubectl context.
NAMESPACE='longhorn-system'
TIMEOUT=600  # seconds per volume

main()
{
    target="$(kubectl -n "$NAMESPACE" get settings.longhorn.io default-engine-image -o jsonpath='{.value}')"
    check_engine_image "$target"

    volumes="$(volumes_to_upgrade "$target")"
    if [ -z "$volumes" ]; then
        printf -- 'All volumes already run %s.\n' "$target"
        return 0
    fi

    printf -- 'Volumes to move to %s:\n' "$target"
    for volume in $volumes; do
        printf -- '  %s\n' "$(volume_summary "$volume")"
    done
    printf -- 'Press <enter> to upgrade them one by one, or Ctrl-C to abort:'
    read -r _

    for volume in $volumes; do
        upgrade_volume "$volume" "$target"
    done

    printf -- 'Done. Engine images still in use:\n'
    kubectl -n "$NAMESPACE" get engineimages.longhorn.io \
        -o jsonpath='{range .items[*]}  {.spec.image}: {.status.refCount} volume(s){"\n"}{end}'
}

# check_engine_image <image>
#
# The target engine must be deployed on the nodes before any volume can switch to it.
check_engine_image()
{
    state="$(kubectl -n "$NAMESPACE" get engineimages.longhorn.io -o json \
        | jq -r --arg image "$1" '.items[] | select(.spec.image == $image)
            | "\(.status.state) \(.status.incompatible)"')"

    if [ "$state" != 'deployed false' ]; then
        printf -- 'Engine image %s is not ready (state/incompatible: %s). Stopping.\n' \
            "$1" "${state:-missing}" >&2
        exit 1
    fi
}

# volumes_to_upgrade <image>
volumes_to_upgrade()
{
    kubectl -n "$NAMESPACE" get volumes.longhorn.io -o json \
        | jq -r --arg image "$1" '.items[] | select(.spec.image != $image) | .metadata.name'
}

# volume_summary <volume>
volume_summary()
{
    kubectl -n "$NAMESPACE" get volumes.longhorn.io "$1" -o json \
        | jq -r '"\(.metadata.name) (\(.status.kubernetesStatus.namespace // "-")/\(.status.kubernetesStatus.pvcName // "-")): \(.status.state), \(.status.robustness), \(.status.currentImage | split(":") | last)"'
}

# volume_field <volume> <jsonpath>
volume_field()
{
    kubectl -n "$NAMESPACE" get volumes.longhorn.io "$1" -o jsonpath="$2"
}

# upgrade_volume <volume> <image>
upgrade_volume()
{
    volume="$1"; image="$2"
    state="$(volume_field "$volume" '{.status.state}')"

    if [ "$state" = 'attached' ]; then
        wait_for_healthy "$volume"
        printf -- 'Live-upgrading %s...\n' "$volume"
    else
        printf -- 'Upgrading %s offline (%s)...\n' "$volume" "$state"
    fi

    kubectl -n "$NAMESPACE" patch volumes.longhorn.io "$volume" --type=merge \
        -p "{\"spec\":{\"image\":\"${image}\"}}" >/dev/null

    elapsed=0
    until [ "$(volume_field "$volume" '{.status.currentImage}')" = "$image" ]; do
        [ "$elapsed" -lt "$TIMEOUT" ] || fail "$volume" "did not switch to the new engine"
        sleep 5; elapsed=$((elapsed + 5))
    done

    [ "$state" != 'attached' ] || wait_for_healthy "$volume"
    printf -- '  %s\n' "$(volume_summary "$volume")"
}

# wait_for_healthy <volume>
#
# Before a live upgrade, and after it: the next volume only starts once this one is attached and
# healthy again, with its replicas rebuilt on the new engine.
wait_for_healthy()
{
    elapsed=0
    until [ "$(volume_field "$1" '{.status.state}/{.status.robustness}')" = 'attached/healthy' ]; do
        [ "$elapsed" -lt "$TIMEOUT" ] || fail "$1" "is not healthy ($(volume_field "$1" '{.status.robustness}'))"
        [ "$elapsed" -gt 0 ] || printf -- '  waiting for %s to be healthy...\n' "$1"
        sleep 5; elapsed=$((elapsed + 5))
    done
}

# fail <volume> <reason>
fail()
{
    printf -- 'Volume %s %s after %ss. Stopping; check it in the Longhorn UI.\n' "$1" "$2" "$TIMEOUT" >&2
    exit 1
}

main "$@"
