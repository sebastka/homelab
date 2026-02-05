#!/bin/sh
set -eux

main()
{
    # reset
    terraform fmt
    terraform validate
    terraform plan -out=tfplan
    # terraform apply tfplan
}

reset()
{
    rm -rf .terraform
    rm -f .terraform.lock.hcl terraform.tfstate* tfplan
    terraform init
}

main "$@"
