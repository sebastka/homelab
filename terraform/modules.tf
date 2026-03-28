module "dns" {
  source = "./dns"

  providers = {
    cloudflare = cloudflare
  }

  cloudflare = var.cloudflare
  domeneshop = var.domeneshop
}

module "linux_containers" {
  source = "./linux_containers"

  providers = {
    proxmox = proxmox
  }

  pve                 = var.pve
  ssh_authorized_keys = var.ssh_authorized_keys
}

module "virtual_machines" {
  source = "./virtual_machines"

  providers = {
    proxmox = proxmox
  }

  pve = var.pve
}
