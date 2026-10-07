#!/bin/sh
set -eu

# ./bootstrap.sh <cluster-name> <full|credentials>
#
# The mode is deliberately not optional: `full` talks to the nodes, `credentials` does not.
#
#   full              Bring up a cluster whose nodes are sitting in maintenance mode: local
#                     credentials, then apply + etcd bootstrap. `topf apply` generates the
#                     machine configs itself, so there is no genconfig step.
#   credentials       Rewrite the local files only: talosconfig, then the kubeconfig and the
#                     sealed-secrets keypair (see kubeconfig.sh). All are derived from the
#                     secrets files in this repo and need no running cluster, so this is how
#                     you recover from a lost config directory or an expired certificate.
main()
{
    export CLUSTER_NAME="$1"
    export TOPFCONFIG="./clusters/${CLUSTER_NAME}/topf.yaml"
    export TALOS_CONFIG_HOME="$XDG_CONFIG_HOME/talos/$CLUSTER_NAME"
    mode="${2:-}"

    [ -f "$TOPFCONFIG" ] || return 1

    case "$mode" in
        full)
            talos_write_talosconfig
            talos_apply
            "$(dirname "$0")/kubeconfig.sh" "$CLUSTER_NAME"
            ;;
        credentials)
            talos_write_talosconfig
            "$(dirname "$0")/kubeconfig.sh" "$CLUSTER_NAME"
            ;;
        *)
            printf -- 'usage: %s <cluster-name> <full|credentials>\n' "$0" >&2
            return 1
            ;;
    esac
}

talos_write_talosconfig()
{
    printf 'Writing talosconfig...\n'
    rm -rf "$TALOS_CONFIG_HOME"
    mkdir -p "$TALOS_CONFIG_HOME"
    topf talosconfig >"$TALOS_CONFIG_HOME/config.yaml"
    ln -sf "$CLUSTER_NAME/config.yaml" "$XDG_CONFIG_HOME/talos/config.yaml"

    # Format and only use first endpoint and node
    yq eval-all -i '
        . head_comment |= "Endpoints: " + (.contexts[env(CLUSTER_NAME)].endpoints| join(", ")) + "\nNodes: " + (.contexts[env(CLUSTER_NAME)].nodes| join(", ")) |
        .contexts[env(CLUSTER_NAME)].endpoints = [.contexts[env(CLUSTER_NAME)].endpoints[0]] |
        .contexts[env(CLUSTER_NAME)].nodes = [.contexts[env(CLUSTER_NAME)].nodes[0]]
        ' "$TALOS_CONFIG_HOME/config.yaml"
}

# Applies to every node, then calls the etcd bootstrap API once all of them took the config.
# topf shows a diff and asks for confirmation before it touches anything.
talos_apply()
{
    topf apply --auto-bootstrap
}

main "$@"
