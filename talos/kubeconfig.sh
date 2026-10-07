#!/bin/sh
set -eu

# ./kubeconfig.sh <cluster-name> [setup]
#
# Writes $XDG_CONFIG_HOME/kube/<cluster>/config.yaml and the sealed-secrets keypair beside it
# (seal.key, seal.crt) from the secrets in this repo, without contacting the cluster. The
# kubeconfig holds one cluster and two users:
#
#   topf@<cluster>  Break-glass admin: a 12h system:masters certificate from `topf kubeconfig`.
#   oidc@<cluster>  Day-to-day access through Authelia via the kubectl oidc-login plugin, landing
#                   on the RBAC bound to the `authelia:` prefixes.
#
# The file is regenerated from scratch on every run, so it also refreshes an expired admin
# certificate. Only the current context is carried over; a first run leaves topf@<cluster>
# current, since OIDC needs Authelia to be running in the cluster.
#
# Add `setup` to run the interactive `kubectl oidc-login setup` flow first, which checks the
# issuer and client against the provider.
main()
{
    export CLUSTER_NAME="$1"
    export TOPFCONFIG="./clusters/${CLUSTER_NAME}/topf.yaml"

    [ -f "$TOPFCONFIG" ] || return 1

    case "${2:-}" in
        '') ;;
        setup) oidc_login_setup ;;
        *)
            printf -- 'usage: %s <cluster-name> [setup]\n' "$0" >&2
            return 1
            ;;
    esac

    kubeconfig="$XDG_CONFIG_HOME/kube/${CLUSTER_NAME}/config.yaml"
    current=''
    [ ! -f "$kubeconfig" ] || current="$(kubectl config current-context --kubeconfig "$kubeconfig" 2>/dev/null || true)"

    printf -- 'Writing %s...\n' "$kubeconfig"
    mkdir -p "$(dirname "$kubeconfig")"

    # Built next to the target and moved into place, so a failed run leaves the old file intact
    tmp="$(mktemp "${kubeconfig}.XXXXXX")"
    trap 'rm -f "$tmp"' EXIT

    topf kubeconfig >"$tmp"
    oidc_add_user "$tmp"

    if [ -n "$current" ]; then
        kubectl config use-context "$current" --kubeconfig "$tmp" >/dev/null 2>&1 \
            || printf -- 'Context %s no longer exists, keeping the default.\n' "$current" >&2
    fi

    # kubectl writes kubeconfigs fully expanded; collapse each cluster, context and user onto one
    # line. Note that any later `kubectl config` write - `use-context` included - re-expands the
    # file, since kubectl serialises the whole structure in its own style.
    yq -i '(.clusters[], .contexts[], .users[]) style = "flow"' "$tmp"
    chmod 600 "$tmp"
    mv "$tmp" "$kubeconfig"

    printf -- 'Current context: %s\n' "$(kubectl config current-context --kubeconfig "$kubeconfig")"
    printf -- 'Switch with: kubectl config use-context <oidc|topf>@%s\n' "$CLUSTER_NAME"

    sealed_secret_write_keys "$(dirname "$kubeconfig")"
}

# sealed_secret_write_keys <dir>
#
# Such that secrets can be sealed/unsealed locally.
#
# The keypair lives in its own file rather than inside the Talos secrets bundle: topf parses
# that bundle into the Talos struct and re-serialises it, so `topf secrets > secrets.sops.yaml`
# would silently drop any key Talos does not know about - taking with it the ability to
# decrypt every SealedSecret in this repo.
#
# Decrypted once up front: inside a pipeline a sops failure would go unnoticed and leave
# empty key files behind.
sealed_secret_write_keys()
{
    printf -- 'Writing %s/seal.{key,crt}...\n' "$1"
    keypair="$(sops -d "./clusters/${CLUSTER_NAME}/sealedsecrets.sops.yaml")"

    for type in key crt; do
        (
            umask 077
            printf -- '%s\n' "$keypair" | yq -r ".${type}" | base64 -d >"$1/seal.${type}"
        )
    done
}

# oidc_add_user <kubeconfig>
#
# The exec calls the plugin binary directly rather than going through `kubectl oidc-login`, so
# a kuberc `credentialPluginAllowlist` can name kubectl-oidc_login instead of having to
# allow kubectl itself - which, being able to run any plugin, would barely be a restriction.
oidc_add_user()
{
    kubectl config set-credentials "oidc@${CLUSTER_NAME}" \
        --kubeconfig "$1" \
        --exec-api-version=client.authentication.k8s.io/v1 \
        --exec-interactive-mode=Never \
        --exec-command=kubectl-oidc_login \
        --exec-arg=get-token \
        --exec-arg="--oidc-issuer-url=$(oidc_value oidcIssuerUrl)" \
        --exec-arg="--oidc-client-id=$(oidc_value oidcClientId)" \
        --exec-arg="--oidc-extra-scope=openid" \
        --exec-arg="--oidc-extra-scope=email" \
        --exec-arg="--oidc-extra-scope=groups" \
        --exec-arg="--oidc-extra-scope=profile" \
        >/dev/null

    # The cluster stanza comes from `topf kubeconfig`
    kubectl config set-context "oidc@${CLUSTER_NAME}" \
        --kubeconfig "$1" \
        --cluster "$CLUSTER_NAME" \
        --user "oidc@${CLUSTER_NAME}" \
        --namespace default \
        >/dev/null
}

oidc_login_setup()
{
    kubectl oidc-login setup \
        --oidc-issuer-url "$(oidc_value oidcIssuerUrl)" \
        --oidc-client-id "$(oidc_value oidcClientId)" \
        --oidc-extra-scope openid \
        --oidc-extra-scope email \
        --oidc-extra-scope groups \
        --oidc-extra-scope profile
}

# oidc_value <key>
oidc_value()
{
    yq -r ".data.${1}" "$TOPFCONFIG"
}

main "$@"
