resource "proxmox_lxc" "db01" {
  hostname             = "db01.${var.pve.domain}"
  ostemplate           = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
  description          = "Database server (MariaDB)"
  tags                 = "database,db,mariadb"
  password             = "changeme"
  target_node          = var.pve.name
  arch                 = "amd64"
  console              = true
  cores                = 4
  memory               = 4096
  swap                 = 0
  ignore_unpack_errors = false
  onboot               = true
  startup              = "up=10"
  start                = true
  ssh_public_keys      = join("\n", var.ssh_authorized_keys)
  unprivileged         = true

  features {
    fuse    = false
    keyctl  = false
    nesting = true
    mknod   = false
    # mount
  }

  network {
    name     = "eth0"
    bridge   = "vmbr0"
    firewall = true
    hwaddr   = "BC:24:11:36:0C:75"
    ip       = "dhcp"
  }

  rootfs {
    storage = var.pve.default_storage_pool
    size    = "128G"
  }

  lifecycle {
    ignore_changes = [
      description,
      ostemplate,
      password,
      ssh_public_keys
    ]
  }
}
