#!/bin/sh
set -eu

# ./init.sh <cluster-name>
main()
{
    export CLUSTER_NAME="$1"
    [ -f "./.${CLUSTER_NAME}.env" ] || return 1
    set -a; . "./.${CLUSTER_NAME}.env"; set +a

    printf 'Generating Talos configuration...\n'
    rm -rf "$TALOS_CONFIG_HOME"
    talosctl gen config "$CLUSTER_NAME" "https://$CONTROL_PLANE_IP:6443" --output-dir "$TALOS_CONFIG_HOME" --install-image "$FACTORY_IMAGE" \
        --config-patch @patch/common/diskSelector.yaml \
        --config-patch @patch/common/longhorn.yaml \
        --config-patch @patch/common/cni-proxy.yaml \
        --config-patch @patch/common/metrics-server.yaml

    ln -sf "$CLUSTER_NAME/talosconfig" "$XDG_CONFIG_HOME/talos/config.yaml"

    wait 'Press enter to apply configuration to control plane nodes...'
    sed 1d nodes.csv | grep -E -v '^#' | grep controlplane | while IFS=, read cluster pve_node role node_name ip; do
        yq -n ".machine.nodeLabels.\"topology.kubernetes.io/region\" = \"$cluster\" | .machine.nodeLabels.\"topology.kubernetes.io/zone\" = \"$node_name\"" \
            > /tmp/labels.yaml

        talosctl apply-config --insecure --nodes "$ip" --file "$TALOS_CONFIG_HOME/controlplane.yaml" \
            --config-patch @patch/cp/vip.yaml \
            --config-patch @patch/cp/etcd-metrics-patch.yaml \
            --config-patch @/tmp/labels.yaml
    done

    talosctl config endpoint $CONTROL_PLANE_IP
    talosctl config node $CONTROL_PLANE_IP

    wait 'Press enter to apply configuration to worker nodes...'
    sed 1d nodes.csv | grep -E -v '^#' | grep worker | while IFS=, read cluster pve_node role node_name ip; do
        yq -n ".machine.nodeLabels.\"topology.kubernetes.io/region\" = \"$cluster\" | .machine.nodeLabels.\"topology.kubernetes.io/zone\" = \"$node_name\"" \
            > /tmp/labels.yaml

        talosctl apply-config --insecure --nodes "$ip" --file "$TALOS_CONFIG_HOME/worker.yaml" \
            --config-patch @patch/worker/vip.yaml \
            --config-patch @patch/worker/longhorn.yaml \
            --config-patch @/tmp/labels.yaml
    done

    wait 'Press enter to bootstrap the cluster...'
    talosctl bootstrap

    printf 'Bootstrapping the cluster, this may take a few minutes...\n'
    sleep 30

    wait 'Press enter to retrieve the kubeconfig file...'
    [ ! -f "$XDG_CONFIG_HOME/kube/config.$CLUSTER_NAME" ] || rm "$XDG_CONFIG_HOME/kube/config.$CLUSTER_NAME"
    talosctl kubeconfig "$XDG_CONFIG_HOME/kube/config.$CLUSTER_NAME"
    ln -sf "config.$CLUSTER_NAME" "$XDG_CONFIG_HOME/kube/config"
}

wait()
{
    printf -- "$1"
    read a
}

main "$@"
