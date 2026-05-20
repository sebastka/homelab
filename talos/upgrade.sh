#!/bin/sh
set -eu

# ./upgrade.sh <cluster-name>
main()
{
    export CLUSTER_NAME="$1"

    [ -f "./clusters/${CLUSTER_NAME}/cluster.env" ] || return 1
    set -a; . "./clusters/${CLUSTER_NAME}/cluster.env"; set +a

    sed 1d "./clusters/${CLUSTER_NAME}/nodes.csv" | grep -E -v '^#' | while IFS=, read cluster pve_node node_name hw_add net_addr; do
        printf -- 'Upgrading node %s (%s) to v%s... Press <enter> to continue:' "$node_name" "$net_addr" "$TALOS_VERSION"
        read keypress </dev/tty

        if lh_has_space_for_eviction "$node_name"; then
            kubectl -n longhorn-system patch node.longhorn.io "$node_name" --type=merge -p '{"spec":{"allowScheduling":false,"evictionRequested":true}}'

            while [ "$(lh_get_replica_count_on_node "$node_name")" -gt 0 ]; do
                printf -- 'Waiting for %d Longhorn replicas to evacuate from %s...\n' \
                    "$(lh_get_replica_count_on_node "$node_name")" "$node_name"
                sleep 10
            done

            talosctl upgrade --nodes "$net_addr" --image "ghcr.io/siderolabs/installer:v${TALOS_VERSION}"

            until kubectl -n longhorn-system get node.longhorn.io "$node_name" >/dev/null 2>&1; do
                printf 'Waiting for Longhorn node %s to come back online...\n' "$node_name"
                sleep 10
            done

            kubectl -n longhorn-system patch node.longhorn.io "$node_name" --type=merge -p '{"spec":{"allowScheduling":true,"evictionRequested":false}}'
        else
            printf -- 'Skipping Longhorn eviction for %s: insufficient space on other nodes.\n' "$node_name"
            kubectl cordon "$node_name"
            kubectl drain "$node_name" --ignore-daemonsets --delete-emptydir-data --timeout=2m || true
            talosctl upgrade --nodes "$net_addr" --image "ghcr.io/siderolabs/installer:v${TALOS_VERSION}" --drain=false
        fi
    done
}

# lh_has_space_for_eviction <node-name>
lh_has_space_for_eviction()
{
    total_replica_size=$(lh_get_total_replica_size "$1")
    total_free=$(lh_get_total_free "$1")
    [ "$total_free" -gt "$total_replica_size" ]
}

# lh_get_total_replica_size <node-name>
lh_get_total_replica_size()
{
    kubectl -n longhorn-system get replicas.longhorn.io -o json \
        | jq --arg node "${1}" \
            '[.items[] | select(.spec.nodeID == $node) | .spec.volumeSize | tonumber] | add // 0'
}

# lh_get_total_free <node-name>
lh_get_total_free()
{
    kubectl -n longhorn-system get nodes.longhorn.io -o json \
        | jq --arg node "${1}" \
            '[.items[] | select(.metadata.name != $node and .spec.allowScheduling == true)
            | .status.diskStatus | to_entries[]
            | (.value.storageAvailable - .value.storageScheduled)] | add // 0'
}

# lh_get_replica_count_on_node <node-name>
lh_get_replica_count_on_node()
{
    kubectl -n longhorn-system get replicas.longhorn.io -o json \
        | jq "[.items[] | select(.spec.nodeID == \"${1}\")] | length"
}

main "$@"
