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
    import_resources
}

import_resources()
{
    terraform import proxmox_lxc.db01 hera/qemu/102
    terraform import proxmox_lxc.db02 hera/qemu/104
    terraform import proxmox_lxc.redis01 hera/qemu/103
    terraform import proxmox_vm_qemu.templatevm hera/qemu/999
    terraform import proxmox_vm_qemu.file01 hera/qemu/101
}

main "$@"
