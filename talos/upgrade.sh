#!/bin/sh
set -eux

# ./upgrade.sh <cluster-name> <talos-version>
main()
{
    export CLUSTER_NAME="$1"
    export TALOS_VERSION="$2"

    [ -f "./clusters/${CLUSTER_NAME}/cluster.env" ] || return 1
    set -a; . "./clusters/${CLUSTER_NAME}/cluster.env"; set +a

    sed 1d "./clusters/${CLUSTER_NAME}/nodes.csv" | grep -E -v '^#' | grep controlplane | while IFS=, read cluster pve_node role node_name hw_add net_addr; do
        printf -- 'Upgrading control plane node %s (%s) to v%s... Press <enter> to continue:' "$node_name" "$net_addr" "$TALOS_VERSION"
        read keypress </dev/tty
        talosctl upgrade --nodes "$net_addr" --image "ghcr.io/siderolabs/installer:v${TALOS_VERSION}"
    done
    
    sed 1d "./clusters/${CLUSTER_NAME}/nodes.csv" | grep -E -v '^#' | grep worker | while IFS=, read cluster pve_node role node_name hw_add net_addr; do
        printf -- 'Upgrading worker node %s (%s) to v%s... Press <enter> to continue:' "$node_name" "$net_addr" "$TALOS_VERSION"
        read keypress </dev/tty
        talosctl upgrade --nodes "$net_addr" --image "ghcr.io/siderolabs/installer:v${TALOS_VERSION}"
    done
}

main "$@"
