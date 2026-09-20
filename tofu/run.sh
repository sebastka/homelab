#!/bin/sh
set -eu

# Plan the root module, show it, and apply on confirmation.

main()
{
    [ ! -f tfplan ] || rm tfplan

    tofu init -upgrade
    tofu fmt -recursive
    tofu validate

    unlock_secrets || return 1

    # -detailed-exitcode: 0 = no changes, 1 = error, 2 = changes.
    # Collect it rather than letting set -e abort on 1 or 2.
    rc=0
    tofu plan -detailed-exitcode -out=tfplan || rc=$?

    [ $rc -ne 0 ] || { printf -- '\nNo changes to apply.\n'; return $rc; }
    [ $rc -ne 1 ] || { printf -- '\nError running tofu plan.\n'; return $rc; }

    printf -- '\nApply the above plan? Press <enter> to continue: '
    read keypress
    tofu apply tfplan
}

# The sops provider decrypts secrets.sops.yaml partway through the plan, and
# gpg-agent's pinentry draws on this same terminal -- the plan's output scrolls
# the prompt away before it can be answered. So unlock here instead, while
# nothing else is writing, and let the plan read from the agent's cache.
unlock_secrets()
{
    GPG_TTY=$(tty) || GPG_TTY=
    export GPG_TTY

    printf -- 'Unlocking secrets.sops.yaml...\n'
    sops -d secrets.sops.yaml >/dev/null && return 0

    printf -- '\nCould not decrypt secrets.sops.yaml. Is the PGP key available?\n' >&2
    return 1
}

main "$@"
