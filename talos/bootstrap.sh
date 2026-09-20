#!/bin/sh
set -eu

# ./bootstrap.sh <cluster-name> <full|credentials|kubeconfig-oidc> [setup]
#
# The mode is deliberately not optional: `full` talks to the nodes, the others do not.
#
#   full              Bring up a cluster whose nodes are sitting in maintenance mode: local
#                     credentials, then apply + etcd bootstrap. `topf apply` generates the
#                     machine configs itself, so there is no genconfig step.
#   credentials       Rewrite the local files only: talosconfig, the sealed-secrets keypair
#                     and a break-glass admin kubeconfig. All three are derived from the
#                     secrets files in this repo and need no running cluster, so this is how
#                     you recover from a lost config directory or an expired certificate.
#   kubeconfig-oidc   Add an oidc@<cluster> user and context to the kubeconfig written by the
#                     modes above, authenticating against Authelia through the kubectl
#                     oidc-login plugin. Add `setup` to run the interactive
#                     `kubectl oidc-login setup` flow first, which checks the issuer and
#                     client against the provider.
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
            sealed_secret_write_keys
            talos_apply
            talos_write_admin_kubeconfig
            ;;
        credentials)
            talos_write_talosconfig
            sealed_secret_write_keys
            talos_write_admin_kubeconfig
            ;;
        kubeconfig-oidc)
            [ "${3:-}" != 'setup' ] || oidc_login_setup
            oidc_write_kubeconfig
            ;;
        *)
            printf -- 'usage: %s <cluster-name> <full|credentials|kubeconfig-oidc> [setup]\n' "$0" >&2
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

# Break-glass admin credentials: a 12h system:masters certificate, minted from the secrets
# bundle without contacting the cluster. Day-to-day access is the OIDC user added below.
#
# Merged rather than overwritten: on a duplicate key the first file in KUBECONFIG wins, so the
# fresh certificate replaces the old one while anything else in the file - notably the oidc@
# user and context - is carried over.
talos_write_admin_kubeconfig()
{
    printf 'Writing admin kubeconfig...\n'
    mkdir -p "$XDG_CONFIG_HOME/kube/${CLUSTER_NAME}"
    kubeconfig="$(kubeconfig_path)"
    tmp="$(mktemp)"

    topf kubeconfig >"$tmp"
    if [ -f "$kubeconfig" ]; then
        current="$(kubectl config current-context --kubeconfig "$kubeconfig" 2>/dev/null || true)"
        KUBECONFIG="${tmp}:${kubeconfig}" kubectl config view --flatten >"${kubeconfig}.new"
        mv "${kubeconfig}.new" "$kubeconfig"
        rm -f "$tmp"
        [ -z "$current" ] || kubectl config use-context "$current" --kubeconfig "$kubeconfig" >/dev/null
    else
        mv "$tmp" "$kubeconfig"
    fi

    kubeconfig_compact
}

kubeconfig_path()
{
    printf -- '%s/kube/%s/config.yaml' "$XDG_CONFIG_HOME" "$CLUSTER_NAME"
}

# kubectl writes kubeconfigs fully expanded; collapse each cluster, context and user onto one
# line. Note that any later `kubectl config` write - `use-context` included - re-expands the
# file, since kubectl serialises the whole structure in its own style.
kubeconfig_compact()
{
    kubeconfig="$(kubeconfig_path)"
    yq -i '(.clusters[], .contexts[], .users[]) style = "flow"' "$kubeconfig"
    chmod 600 "$kubeconfig"
}

# Such that secrets can be sealed/unsealed locally.
#
# The keypair lives in its own file rather than inside the Talos secrets bundle: topf parses
# that bundle into the Talos struct and re-serialises it, so `topf secrets > secrets.sops.yaml`
# would silently drop any key Talos does not know about - taking with it the ability to
# decrypt every SealedSecret in this repo.
sealed_secret_write_keys()
{
    for type in key crt; do
        sops -d "./clusters/${CLUSTER_NAME}/sealedsecrets.sops.yaml" \
            | yq -r ".${type}" \
            | base64 -d \
            >"$TALOS_CONFIG_HOME/seal.${type}"
    done
}

# Adds an OIDC user and context to the admin kubeconfig rather than writing a second file:
# authentication goes through Authelia via the kubectl oidc-login plugin and lands on the RBAC
# bound to the `authelia:` prefixes. The cluster stanza is already in the file.
#
# The exec calls the plugin binary directly rather than going through `kubectl oidc-login`, so
# a kuberc `credentialPluginAllowlist` can name kubectl-oidc_login instead of having to
# allow kubectl itself - which, being able to run any plugin, would barely be a restriction.
oidc_write_kubeconfig()
{
    kubeconfig="$(kubeconfig_path)"
    if [ ! -f "$kubeconfig" ]; then
        printf -- 'no %s yet - run `%s %s credentials` first\n' "$kubeconfig" "$0" "$CLUSTER_NAME" >&2
        return 1
    fi

    printf -- 'Adding the oidc@%s user and context to %s...\n' "$CLUSTER_NAME" "$kubeconfig"

    kubectl config set-credentials "oidc@${CLUSTER_NAME}" \
        --kubeconfig "$kubeconfig" \
        --exec-api-version=client.authentication.k8s.io/v1 \
        --exec-interactive-mode=Never \
        --exec-command=kubectl-oidc_login \
        --exec-arg=get-token \
        --exec-arg="--oidc-issuer-url=$(oidc_value oidcIssuerUrl)" \
        --exec-arg="--oidc-client-id=$(oidc_value oidcClientId)" \
        --exec-arg="--oidc-extra-scope=openid" \
        --exec-arg="--oidc-extra-scope=email" \
        --exec-arg="--oidc-extra-scope=groups" \
        --exec-arg="--oidc-extra-scope=profile"

    kubectl config set-context "oidc@${CLUSTER_NAME}" \
        --kubeconfig "$kubeconfig" \
        --cluster "$CLUSTER_NAME" \
        --user "oidc@${CLUSTER_NAME}" \
        --namespace default

    # Day-to-day access, so make it the default; `credentials` preserves whatever is current
    kubectl config use-context "oidc@${CLUSTER_NAME}" --kubeconfig "$kubeconfig"
    kubeconfig_compact

    printf -- 'Break-glass admin access: kubectl config use-context topf@%s\n' "$CLUSTER_NAME"
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
