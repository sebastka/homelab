#!/bin/sh
set -eu

# ./mk_kubeconfig.sh <cluster-name>
main()
{
    export CLUSTER_NAME="$1"
    [ -f "./clusters/${CLUSTER_NAME}/cluster.env" ] || return 1
    set -a; . "./clusters/${CLUSTER_NAME}/cluster.env"; set +a

    # Decrypt talsecrets if needed
    [ -f "./clusters/${CLUSTER_NAME}/talsecret.sops.yaml" ] || \
        sops -d "./clusters/${CLUSTER_NAME}/talsecret.sops.enc.yaml" > "./clusters/${CLUSTER_NAME}/talsecret.sops.yaml"

    export CERTS_K8S_CRT="$(yq -r '.certs.k8s.crt' "./clusters/${CLUSTER_NAME}/talsecret.sops.yaml")"

    # Generate command - not needed anymore
    # kubectl oidc-login setup \
    #     --oidc-issuer-url ${OIDC_ISSUER_URL} \
    #     --oidc-client-id ${OIDC_CLIENT_ID} \
    #     --oidc-extra-scope email \
    #     --oidc-extra-scope groups \
    #     --oidc-extra-scope profile

    # Generate base kubeconfig
    yq -n \
        '.apiVersion = "v1" |
        .kind = "Config" |
        .current-context = "oidc@" + env(CLUSTER_NAME) |
        .clusters[0].name = env(CLUSTER_NAME) |
        .clusters[0].cluster.server = "https://" + env(TALOS_VIP) + ":6443" |
        .clusters[0].cluster.certificate-authority-data = env(CERTS_K8S_CRT) |
        .contexts[0].name = "oidc@" + env(CLUSTER_NAME) |
        .contexts[0].context.cluster = env(CLUSTER_NAME) |
        .contexts[0].context.user = "oidc@" + env(CLUSTER_NAME) |
        .contexts[0].context.namespace = "default" |
        .users[0].name = "admin@" + env(CLUSTER_NAME) |
        .users[0].user.client-certificate-data = "XXX" |
        .users[0].user.client-key-data = "YYY"' \
        > "$XDG_CONFIG_HOME/kube/config.${CLUSTER_NAME}-oidc"

    ln -sf "config.${CLUSTER_NAME}-oidc" "$XDG_CONFIG_HOME/kube/config"

    # Set up OIDC user with kubectl oidc-login plugin
    kubectl config set-credentials oidc \
        --exec-api-version=client.authentication.k8s.io/v1 \
        --exec-interactive-mode=Never \
        --exec-command=kubectl \
        --exec-arg=oidc-login \
        --exec-arg=get-token \
        --exec-arg="--oidc-issuer-url=${OIDC_ISSUER_URL}" \
        --exec-arg="--oidc-client-id=${OIDC_CLIENT_ID}" \
        --exec-arg="--oidc-extra-scope=email" \
        --exec-arg="--oidc-extra-scope=groups" \
        --exec-arg="--oidc-extra-scope=profile"
}

main "$@"
