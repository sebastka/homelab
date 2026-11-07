#!/bin/sh
set -eu

# ./upgrade.sh <cluster-name> [upgrade|reboot]
#
#   upgrade  (default)  Bring each node to its installer image: the `talosVersion` and schematic
#                       set in clusters/<cluster>/topf.yaml, so a schematic change alone (an added
#                       extension or kernel argument) rolls the node too. topf compares the image
#                       per node, skips nodes already there, and cordons, drains, reboots and
#                       uncordons each one itself.
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

    if [ "$action" = 'upgrade' ] && ! upgrade_pending "$host"; then
        printf -- 'Node %s (%s) already runs v%s with its configured schematic, skipping.\n' \
            "$node_name" "$ip" "$version"
        return 0
    fi

    if [ "$action" = 'upgrade' ]; then
        printf -- 'Upgrading node %s (%s) to v%s... Press <enter> to continue:' "$node_name" "$ip" "$version"
    else
        printf -- 'Rebooting node %s (%s)... Press <enter> to continue:' "$node_name" "$ip"
    fi
    read keypress

    nfs_clients_off "$node_name"

    evicted='false'
    if [ "${EVICT:-true}" = 'true' ] && lh_can_evict "$node_name"; then
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

    # nfs_clients_off may have cordoned the node before topf did; topf only undoes its own
    kubectl uncordon "$node_name" >/dev/null 2>&1 || true

    # topf exits 0 when it skips a node, so confirm the node really moved before the next one
    if [ "$action" = 'upgrade' ] && upgrade_pending "$host"; then
        printf -- 'Node %s still differs from its configured installer image. Stopping.\n' \
            "$node_name" >&2
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

# upgrade_pending <host>
#
# Asks topf, which compares the node's installer image (Talos version and schematic) with the one
# configured for it. Comparing the Talos version alone would miss a schematic change, such as an
# added extension or kernel argument, and skip the node. The dry run exits 2 when an upgrade is
# pending and 0 when the node is current.
upgrade_pending()
{
    set +e
    topf upgrade --dry-run --confirm=false --progress PLAIN --nodes-filter "^${1}\$" >/dev/null 2>&1
    rc=$?
    set -e

    case "$rc" in
        0) return 1 ;;
        2) return 0 ;;
        *)
            printf -- 'Could not tell whether %s needs an upgrade (topf exited %s). Stopping.\n' \
                "$1" "$rc" >&2
            exit 1
            ;;
    esac
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

# lh_can_evict <node-name>
#
# Whether every replica on the node has somewhere to go. A replica may only move to another
# schedulable node that does not already hold a replica of the same volume (Longhorn's hard
# anti-affinity) and has room for it. A total of the free space everywhere is not enough: with
# 2-replica volumes on 3 nodes, a replica leaving one node can only go to the third one, which
# may be full while the second has plenty (dike, 2026-11-07: the eviction waited forever).
# Places the replicas largest first, each on the eligible node with the most room left.
lh_can_evict()
{
    blocked="$(lh_eviction_blockers "$1")"
    [ -n "$blocked" ] || return 0
    printf -- 'Longhorn cannot evict %s: no other node can take a replica of %s.\n' \
        "$1" "$(printf '%s' "$blocked" | tr '\n' ' ')"
    return 1
}

# lh_eviction_blockers <node-name>: the volumes whose replica on the node has nowhere to go.
# The lists go through stdin (jq -s): as --argjson arguments they exceed the argument size limit.
# Only a volume's real replicas count: all of them while it is detached (they are all stopped),
# its running ones while it is attached. A stopped replica of an attached volume is a stale copy
# from a node that was away (e.g. rebooted without eviction): Longhorn drops it rather than moving
# it, and it does not hold a node either.
lh_eviction_blockers()
{
    { kubectl -n longhorn-system get replicas.longhorn.io -o json
      kubectl -n longhorn-system get nodes.longhorn.io -o json
      kubectl -n longhorn-system get volumes.longhorn.io -o json; } \
    | jq -s -r --arg node "$1" '
        .[0] as $r | .[1] as $n
        | (.[2].items | map({key: .metadata.name, value: .status.state}) | from_entries) as $state
        | [$r.items[] | select($state[.spec.volumeName] != "attached" or .status.currentState == "running")] as $reps
        | ($n.items
            | map(select(.metadata.name != $node and .spec.allowScheduling == true)
                | {key: .metadata.name,
                   value: ([.status.diskStatus | to_entries[]
                            | .value.storageAvailable - .value.storageScheduled] | add // 0)})
            | from_entries) as $free
        | [$reps[] | select(.spec.nodeID == $node)]
        | sort_by(-(.spec.volumeSize | tonumber))
        | reduce .[] as $x ({free: $free, blocked: []};
            ($x.spec.volumeName) as $v
            | ($x.spec.volumeSize | tonumber) as $size
            | [$reps[] | select(.spec.volumeName == $v and .spec.nodeID != $node) | .spec.nodeID] as $holders
            | ([.free | to_entries[]
                | select((.key as $k | $holders | index($k)) == null and .value >= $size)]
               | sort_by(-.value) | .[0].key) as $to
            | if $to == null then .blocked += [$v] else .free[$to] -= $size end)
        | .blocked | unique[]'
}

# nfs_clients_off <node-name>
#
# The NFS server is a KubeVirt VM (storage/file), pinned to its node by PCI passthrough. A drain
# evicts it alongside the pods that mount its exports, in no particular order: a client left on
# the node after the server is gone hangs in its NFS unmount, the kubelet never finishes removing
# it, and the drain waits for it forever (deluged on hera, 2026-11-07). So on a node running a VM,
# its pods with an NFS volume are moved first, while the server still answers: cordoned, so they
# come back on another node.
nfs_clients_off()
{
    vms="$(kubectl get vmi -A -o json | jq --arg node "$1" '[.items[] | select(.status.nodeName == $node)] | length')"
    [ "$vms" -gt 0 ] || return 0

    claims="$(kubectl get pv -o json | jq -c '[.items[] | select(.spec.nfs and .spec.claimRef)
        | "\(.spec.claimRef.namespace)/\(.spec.claimRef.name)"]')"
    clients="$(kubectl get pods -A --field-selector "spec.nodeName=$1" -o json \
        | jq -r --argjson claims "$claims" '.items[] | .metadata.namespace as $ns
            | select([.spec.volumes[]? | .persistentVolumeClaim.claimName // empty | "\($ns)/\(.)"]
                     | any(. as $c | $claims | index($c)))
            | "\($ns) \(.metadata.name)"')"
    [ -n "$clients" ] || return 0

    printf -- 'Moving the NFS clients off %s before its VM is evicted...\n' "$1"
    kubectl cordon "$1" >/dev/null
    echo "$clients" | while read -r ns pod; do
        kubectl -n "$ns" delete pod "$pod" --wait=true --timeout=300s
    done
}

# lh_get_replica_count_on_node <node-name>
lh_get_replica_count_on_node()
{
    kubectl -n longhorn-system get replicas.longhorn.io -o json \
        | jq "[.items[] | select(.spec.nodeID == \"${1}\")] | length"
}

main "$@"
