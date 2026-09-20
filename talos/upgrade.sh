#!/bin/sh
set -eu

# ./upgrade.sh <cluster-name> [upgrade|reboot]
#
#   upgrade  (default)  Upgrade Talos to the `talosVersion` set in clusters/<cluster>/topf.yaml.
#                       topf compares the installer image per node, skips nodes already there,
#                       and cordons, drains, reboots and uncordons each one itself.
#   reboot              Roll the nodes without changing versions, for settings that only take
#                       effect when the machine boots (e.g. `allowDiscards`, which is applied
#                       when LUKS opens the volume).
#
# Neither knows about Longhorn, so replicas are evacuated here first and scheduling is restored
# afterwards. Evacuating moves every replica off the node and rebuilds it again on return, which
# for a short reboot costs far more time than the degradation it avoids. Set EVICT=false to
# cordon and drain only, leaving 2-replica volumes single-replica while the node is away.
main()
{
    export CLUSTER_NAME="$1"
    export TOPFCONFIG="./clusters/${CLUSTER_NAME}/topf.yaml"
    action="${2:-upgrade}"

    [ -f "$TOPFCONFIG" ] || return 1
    case "$action" in
        upgrade|reboot) ;;
        *) printf -- 'usage: %s <cluster-name> [upgrade|reboot]\n' "$0" >&2; return 1 ;;
    esac

    talos_version="$(yq -r '.talosVersion' "$TOPFCONFIG")"

    check_config_drift

    # The node list is read up front instead of being piped into the loop: topf asks for
    # confirmation on stdin, and with a pipe it would consume the remaining node lines as
    # answers rather than reading the terminal, then skip the upgrade.
    nodes="$(yq -r '.nodes[] | [.host, .ip, .data.zone] | join(",")' "$TOPFCONFIG")"

    for node in $nodes; do
        roll_node \
            "$(echo "$node" | cut -d, -f1)" \
            "$(echo "$node" | cut -d, -f2)" \
            "$(echo "$node" | cut -d, -f3)" \
            "$talos_version" \
            "$action"
    done
}

# Rolling a node only activates configuration that is already on it, so an unapplied change
# means an eviction and reboot for nothing. This warns rather than applying: `topf apply` is a
# change in its own right and wants its own diff review, not one buried in a reboot loop.
check_config_drift()
{
    printf -- 'Checking whether the nodes match %s...\n' "$TOPFCONFIG"

    set +e
    topf apply --dry-run --confirm=false >/dev/null 2>&1
    rc=$?
    set -e

    case "$rc" in
        0) printf -- '  Nodes are in sync.\n'; return 0 ;;
        2) printf -- '  Pending changes: the nodes do not match the config.\n' ;;
        *) printf -- '  Could not determine drift (topf exited %s).\n' "$rc" ;;
    esac

    printf -- '  Review with `topf apply --dry-run` and apply them first.\n'
    printf -- '  Press <enter> to continue anyway, or Ctrl-C to abort:'
    read keypress
}

# roll_node <host> <ip> <node-name> <talos-version> <action>
roll_node()
{
    host="$1"; ip="$2"; node_name="$3"; version="$4"; action="$5"

    if [ "$action" = 'upgrade' ] && [ "$(talos_version_on_node "$ip")" = "v${version}" ]; then
        printf -- 'Node %s (%s) already runs v%s, skipping.\n' "$node_name" "$ip" "$version"
        return 0
    fi

    if [ "$action" = 'upgrade' ]; then
        printf -- 'Upgrading node %s (%s) to v%s... Press <enter> to continue:' "$node_name" "$ip" "$version"
    else
        printf -- 'Rebooting node %s (%s)... Press <enter> to continue:' "$node_name" "$ip"
    fi
    read keypress

    evicted='false'
    if [ "${EVICT:-true}" = 'true' ] && lh_has_space_for_eviction "$node_name"; then
        evicted='true'
        kubectl -n longhorn-system patch node.longhorn.io "$node_name" --type=merge -p '{"spec":{"allowScheduling":false,"evictionRequested":true}}'

        while [ "$(lh_get_replica_count_on_node "$node_name")" -gt 0 ]; do
            printf -- 'Waiting for %d Longhorn replicas to evacuate from %s...\n' \
                "$(lh_get_replica_count_on_node "$node_name")" "$node_name"
            sleep 10
        done
    else
        printf -- 'Proceeding without Longhorn eviction for %s.\n' "$node_name"
    fi

    if [ "$action" = 'upgrade' ]; then
        topf upgrade --nodes-filter "^${host}\$"
    else
        # --drain cordons and evicts pods before the reboot; topf has no reboot of its own
        talosctl reboot --nodes "$ip" --drain
        wait_for_node_ready "$node_name"
        kubectl uncordon "$node_name" >/dev/null 2>&1 || true
    fi

    until kubectl -n longhorn-system get node.longhorn.io "$node_name" >/dev/null 2>&1; do
        printf 'Waiting for Longhorn node %s to come back online...\n' "$node_name"
        sleep 10
    done

    [ "$evicted" = 'false' ] || kubectl -n longhorn-system patch node.longhorn.io "$node_name" --type=merge -p '{"spec":{"allowScheduling":true,"evictionRequested":false}}'

    # topf exits 0 when it skips a node, so confirm the node really moved before the next one
    if [ "$action" = 'upgrade' ] && [ "$(talos_version_on_node "$ip")" != "v${version}" ]; then
        printf -- 'Node %s did not reach v%s (reports %s). Stopping.\n' \
            "$node_name" "$version" "$(talos_version_on_node "$ip")" >&2
        exit 1
    fi

    # Neither topf nor talosctl waits for Longhorn: going on while replicas are still rebuilding
    # would leave the next node's volumes single-replica
    lh_wait_for_healthy_volumes
}

# wait_for_node_ready <node-name>
wait_for_node_ready()
{
    until [ "$(kubectl get node "$1" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)" = 'True' ]; do
        printf 'Waiting for node %s to become Ready...\n' "$1"
        sleep 10
    done
}

# talos_version_on_node <ip>
talos_version_on_node()
{
    talosctl version --short --nodes "$1" 2>/dev/null | awk '/Tag:/ {print $2; exit}'
}

lh_wait_for_healthy_volumes()
{
    while [ "$(lh_get_unhealthy_volume_count)" -gt 0 ]; do
        printf -- 'Waiting for %d Longhorn volumes to rebuild...\n' \
            "$(lh_get_unhealthy_volume_count)"
        sleep 10
    done
}

# Detached volumes report robustness "unknown", so only attached ones are counted
lh_get_unhealthy_volume_count()
{
    kubectl -n longhorn-system get volumes.longhorn.io -o json \
        | jq '[.items[] | select(.status.state == "attached" and .status.robustness != "healthy")] | length'
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
