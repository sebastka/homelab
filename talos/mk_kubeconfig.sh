#!/bin/sh
set -eu

export CLUSTER_NAME="$1"

set -a;
. ./.env
. "./clusters/${CLUSTER_NAME}.env"
set +a

# kubectl oidc-login setup \
#     --oidc-issuer-url ${OIDC_ISSUER_URL} \
#     --oidc-client-id ${OIDC_CLIENT_ID} \
#     --oidc-extra-scope email \
#     --oidc-extra-scope groups \
#     --oidc-extra-scope profile

[ ! -f "$XDG_CONFIG_HOME/kube/config.${CLUSTER_NAME}-oidc" ] || rm "$XDG_CONFIG_HOME/kube/config.${CLUSTER_NAME}-oidc"

envsubst '${CLUSTER_NAME},${CONTROL_PLANE_IP},${CA_DATA_BASE64},${OIDC_ISSUER_URL},${OIDC_CLIENT_ID}' \
    < kubeconfig.tmpl.yaml \
    > "$XDG_CONFIG_HOME/kube/config.${CLUSTER_NAME}-oidc"

ln -sf "config.${CLUSTER_NAME}-oidc" "$XDG_CONFIG_HOME/kube/config"

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
