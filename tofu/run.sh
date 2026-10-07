#!/bin/sh
set -eu

# Plan the root module, show it, and apply on confirmation. Every secret comes
# from direnv (.envrc), which decrypts secrets.sops.yaml once when the shell
# enters this directory; this script only checks that it did. Nothing here
# touches gpg, so pinentry never has to compete with the plan for the terminal.

# Set by .envrc, so its absence means direnv did not run.
REQUIRED_VARS='TF_VAR_state_encryption_passphrase TF_VAR_lxc_passwords CLOUDFLARE_API_TOKEN PROXMOX_VE_API_TOKEN'

main()
{
    check_env || return 1

    [ ! -f tfplan ] || rm tfplan

    tofu init -upgrade
    tofu fmt -recursive
    tofu validate

    # -detailed-exitcode: 0 = no changes, 1 = error, 2 = changes.
    # Collect it rather than letting set -e abort on 1 or 2.
    rc=0
    tofu plan -detailed-exitcode -out=tfplan || rc=$?

    [ $rc -ne 0 ] || { printf -- '\nNo changes to apply.\n'; return $rc; }
    [ $rc -ne 1 ] || { printf -- '\nError running tofu plan.\n'; return $rc; }

    printf -- '\nApply the above plan? Press <enter> to continue: '
    read -r _keypress
    tofu apply tfplan
}

check_env()
{
    missing=''
    for name in $REQUIRED_VARS; do
        eval "value=\${$name:-}"
        [ -n "$value" ] || missing="$missing $name"
    done

    [ -n "$missing" ] || return 0

    printf -- 'Missing from the environment:%s\n' "$missing" >&2
    printf -- 'Run from tofu/ with direnv allowed: direnv allow\n' >&2
    return 1
}

main "$@"
