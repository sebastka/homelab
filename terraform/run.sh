#!/bin/sh
set -u

main()
{
    set -a; . ./.env; set +a
    [ ! -f tfplan ] || rm tfplan

    terraform fmt
    terraform validate

    terraform plan -out=tfplan -detailed-exitcode
    rc=$?

    [ $rc -ne 0 ] || { printf -- '\nNo changes to apply.\n'; return $rc; }
    [ $rc -ne 1 ] || { printf -- '\nError running terraform plan.\n'; return $rc; }

    printf -- '\nApply the above plan? Press <enter> to continue: '
    read keypress
    terraform apply tfplan
}

main "$@"
