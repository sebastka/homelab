#!/bin/sh
set -eu

# ./init.sh <cluster-name>
main()
{
    export CLUSTER_NAME="$1"
    [ -f "./clusters/${CLUSTER_NAME}/cluster.env" ] || return 1
    set -a; . "./clusters/${CLUSTER_NAME}/cluster.env"; set +a

    # Hacky installation of Cilium during cluster bootstrap
    # yq -n \
    #     '.cluster.inlineManifests[0].name = "cilium-install" |
    #     .cluster.inlineManifests[0].contents = loadstr("/tmp/cilium-helm.yaml")' \
    #     >/tmp/cilium-install.yaml
    # printf -- '---\ncluster:\n  inlineManifests:\n    - name: cilium\n      contents: |\n' \
    #     >/tmp/cilium-install.yaml
    # helm template cilium oci://quay.io/cilium/charts/cilium \
    #     --version 1.19.1 \
    #     --namespace kube-system \
    #     -f ../k8s/infrastructure/network/cilium/values.yaml \
    #     | sed 's/^/        /' \
    #     >>/tmp/cilium-install.yaml

    # Extracting the Sealed Secrets controller certificate and key from the SOPS encrypted secret file
    export SEALED_SECRETS_CRT="$(sops -d "./clusters/${CLUSTER_NAME}/talsecret.sops.enc.yaml" | yq -r '.certs.sealedsecrets.crt')"
    export SEALED_SECRETS_KEY="$(sops -d "./clusters/${CLUSTER_NAME}/talsecret.sops.enc.yaml" | yq -r '.certs.sealedsecrets.key')"

    printf 'Generating Talos configuration...\n'
    rm -rf "$TALOS_CONFIG_HOME"
    talhelper genconfig \
        --config-file "./clusters/${CLUSTER_NAME}/talconfig.yaml" \
        --secret-file "./clusters/${CLUSTER_NAME}/talsecret.sops.enc.yaml" \
        --no-gitignore \
        --out-dir "$TALOS_CONFIG_HOME"
    ln -sf "$CLUSTER_NAME/talosconfig" "$XDG_CONFIG_HOME/talos/config.yaml"

    wait 'Press enter to apply configuration to control plane nodes...'
    sed 1d "./clusters/${CLUSTER_NAME}/nodes.csv" | grep -E -v '^#' | grep controlplane | while IFS=, read cluster pve_node role node_name hw_add net_addr; do
        talosctl apply-config --insecure --talosconfig="$TALOS_CONFIG_HOME/talosconfig" --nodes "${net_addr}" --file "$TALOS_CONFIG_HOME/talmox-${node_name}.talmox.hera.home.karlsen.fr.yaml"
    done

    wait 'Press enter to apply configuration to worker nodes...'
    sed 1d "./clusters/${CLUSTER_NAME}/nodes.csv" | grep -E -v '^#' | grep worker | while IFS=, read cluster pve_node role node_name hw_add net_addr; do
        talosctl apply-config --insecure --talosconfig="$TALOS_CONFIG_HOME/talosconfig" --nodes "${net_addr}" --file "$TALOS_CONFIG_HOME/talmox-${node_name}.talmox.hera.home.karlsen.fr.yaml"
    done

    wait 'Press enter to bootstrap the cluster...'
    talosctl bootstrap --talosconfig="$TALOS_CONFIG_HOME/talosconfig" --nodes "${CONTROL_PLANE_IP}"
    printf 'Bootstrapping the cluster, this may take a few minutes...\n'
    sleep 30

    wait 'Press enter to retrieve the kubeconfig file...'
    [ ! -f "$XDG_CONFIG_HOME/kube/config.$CLUSTER_NAME" ] || rm "$XDG_CONFIG_HOME/kube/config.$CLUSTER_NAME"
    talosctl kubeconfig "$XDG_CONFIG_HOME/kube/config.$CLUSTER_NAME" --nodes "$CONTROL_PLANE_IP"
    ln -sf "config.$CLUSTER_NAME" "$XDG_CONFIG_HOME/kube/config"
}

wait()
{
    printf -- "$1"
    read a
}

main "$@"
