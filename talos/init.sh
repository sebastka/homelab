#!/bin/sh
set -eu

# ./init.sh <cluster-name>
main()
{
    export CLUSTER_NAME="$1"
    export TALOS_CONFIG_HOME="$XDG_CONFIG_HOME/talos/$CLUSTER_NAME"
    [ -f "./clusters/${CLUSTER_NAME}/cluster.env" ] || return 1
    set -a; . "./clusters/${CLUSTER_NAME}/cluster.env"; set +a
    
    talos_generate
    talos_apply
    talos_bootstrap
    talos_get_kubeconfig
    sealed_secret_write_keys
}

talos_generate()
{
    printf 'Generating Talos configuration...\n'
    rm -rf "$TALOS_CONFIG_HOME"
    talhelper genconfig \
        --config-file "./clusters/${CLUSTER_NAME}/talconfig.yaml" \
        --secret-file "./clusters/${CLUSTER_NAME}/talsecret.sops.enc.yaml" \
        --no-gitignore \
        --out-dir "$TALOS_CONFIG_HOME"
    mv "$TALOS_CONFIG_HOME/talosconfig" "$TALOS_CONFIG_HOME/config.yaml"
    ln -sf "$CLUSTER_NAME/config.yaml" "$XDG_CONFIG_HOME/talos/config.yaml"

    # Format and only use first endpoint and node
    yq eval-all -i '
        . head_comment |= "Endpoints: " + (.contexts[env(CLUSTER_NAME)].endpoints| join(", ")) + "\nNodes: " + (.contexts[env(CLUSTER_NAME)].nodes| join(", ")) |
        .contexts[env(CLUSTER_NAME)].endpoints = [.contexts[env(CLUSTER_NAME)].endpoints[0]] |
        .contexts[env(CLUSTER_NAME)].nodes = [.contexts[env(CLUSTER_NAME)].nodes[0]]
        ' "$TALOS_CONFIG_HOME/config.yaml"
}

talos_apply()
{
    printf -- 'Press enter to apply configuration to nodes...'
    read keypress

    sed 1d "./clusters/${CLUSTER_NAME}/nodes.csv" | grep -E -v '^#' | while IFS=, read cluster pve_node node_name hw_add net_addr; do
        talosctl apply-config --insecure \
            --nodes "${net_addr}" \
            --talosconfig "$TALOS_CONFIG_HOME/config.yaml" \
            --file "$TALOS_CONFIG_HOME/talmox-${node_name}.talmox.hera.home.karlsen.fr.yaml"
    done
}

talos_bootstrap()
{
    printf -- 'Press enter to bootstrap the cluster...'
    read keypress

    talosctl bootstrap --nodes "${CONTROL_PLANE_IP}" \
        --talosconfig "$TALOS_CONFIG_HOME/config.yaml"
    printf 'Bootstrapping the cluster, this may take a few minutes...\n'
    sleep 30
}

talos_get_kubeconfig()
{
    printf -- 'Press enter to retrieve the kubeconfig file...'
    read keypress

    [ ! -d "$XDG_CONFIG_HOME/kube/$CLUSTER_NAME" ] || rm -rf "$XDG_CONFIG_HOME/kube/$CLUSTER_NAME"
    mkdir -p "$XDG_CONFIG_HOME/kube/$CLUSTER_NAME"

    talosctl kubeconfig "$XDG_CONFIG_HOME/kube/$CLUSTER_NAME/config.yaml" \
        --nodes "$CONTROL_PLANE_IP" \
        --talosconfig "$TALOS_CONFIG_HOME/config.yaml"

    ln -sf "$CLUSTER_NAME/config.yaml" "$XDG_CONFIG_HOME/kube/config"
}

# Such that secrets can be sealed/unsealed locally
sealed_secret_write_keys()
{
    for type in key crt; do
        sops -d "./clusters/${CLUSTER_NAME}/talsecret.sops.enc.yaml" \
            | yq -r ".certs.sealedsecrets.${type}" \
            | base64 -d \
            >"$TALOS_CONFIG_HOME/seal.${type}"
    done
}

main "$@"
