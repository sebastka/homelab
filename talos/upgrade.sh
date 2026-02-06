#!/bin/sh
set -eux

# ./upgrade.sh <cluster-name>
main()
{
    export CLUSTER_NAME="$1"
    [ -f "./clusters/${CLUSTER_NAME}.env" ] || return 1
    set -a; . "./clusters/${CLUSTER_NAME}.env"; set +a

    for CP_IP in $TALOS_CPS; do
        talosctl upgrade --nodes "$CP_IP" --image "ghcr.io/siderolabs/installer:v${TALOS_VERSION}" --preserve
    done
    
    for WORKER_IP in $TALOS_WORKERS; do
        talosctl upgrade --nodes "$WORKER_IP" --image "ghcr.io/siderolabs/installer:v${TALOS_VERSION}" --preserve
    done
}

main "$@"
