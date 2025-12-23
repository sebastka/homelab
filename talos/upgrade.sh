#!/bin/sh
set -eux

main()
{
    set -a; . ./.env; set +a

    for CP_IP in $TALOS_CPS; do
        talosctl upgrade --nodes "$CP_IP" --image "ghcr.io/siderolabs/installer:v${TALOS_VERSION}" --preserve
    done
    
    for WORKER_IP in $TALOS_WORKERS; do
        talosctl upgrade --nodes "$WORKER_IP" --image "ghcr.io/siderolabs/installer:v${TALOS_VERSION}" --preserve
    done
}

main
