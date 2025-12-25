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
    talosctl gen config "$CLUSTER_NAME" "https://$CONTROL_PLANE_IP:6443" --output-dir "$TALOS_CONFIG_HOME" --install-image "$FACTORY_IMAGE"\
        --config-patch @patch/k8s/gatewayapi.yaml \
        --config-patch @patch/cilium/cilium.yaml \
        --config-patch @patch/talos/diskSelector.yaml \
        --config-patch @patch/longhorn/requirements.yaml --config-patch @patch/longhorn/disk.yaml --config-patch @patch/longhorn/mount.yaml

    ln -sf "$CLUSTER_NAME/talosconfig" "$XDG_CONFIG_HOME/talos/config.yaml"

    wait 'Press enter to apply configuration to control plane nodes...'
    for CP_IP in $TALOS_CPS; do
        talosctl apply-config --insecure --nodes "$CP_IP" --file "$TALOS_CONFIG_HOME/controlplane.yaml" \
            --config-patch @patch/talos/vip-machine.yaml
    done

    talosctl config endpoint $CONTROL_PLANE_IP
    talosctl config node $CONTROL_PLANE_IP

    wait 'Press enter to apply configuration to worker nodes...'
    for WORKER_IP in $TALOS_WORKERS; do
        talosctl apply-config --insecure --nodes "$WORKER_IP" --file "$TALOS_CONFIG_HOME/worker.yaml" \
            --config-patch @patch/talos/vip-cluster.yaml
    done

    wait 'Press enter to bootstrap the cluster...'
    talosctl bootstrap

    printf 'Bootstrapping the cluster, this may take a few minutes...\n'
    sleep 30

    wait 'Press enter to retrieve the kubeconfig file...'
    rm "$XDG_CONFIG_HOME/kube/config.$CLUSTER_NAME"
    talosctl kubeconfig "$XDG_CONFIG_HOME/kube/config.$CLUSTER_NAME"
    ln -sf "config.$CLUSTER_NAME" "$XDG_CONFIG_HOME/kube/config"
}

wait()
{
    printf -- "$1"
    read a
}

main "$@"
