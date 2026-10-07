module "dns" {
  source = "./dns"

  providers = {
    cloudflare = cloudflare
  }

  domeneshop = var.domeneshop
}

module "virtual_machines_hera" {
  source    = "./virtual_machines"
  providers = { proxmox = proxmox.hera }

  pve                 = var.pve["hera"]
  talos_nodes         = local.talos_nodes_hera
  vms                 = local.vms_hera
  ssh_authorized_keys = var.ssh_authorized_keys
  containers          = local.containers_hera
  lxc_passwords       = var.lxc_passwords
}
