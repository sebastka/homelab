resource "proxmox_lxc" "db02" {
  hostname             = "db02.${var.pve.domain}"
  ostemplate           = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
  description          = "Database server (PostgreSQL)"
  tags                 = "database,db,postgresql,postgres"
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
    hwaddr   = "BC:24:11:F5:DB:10"
    ip       = "dhcp"
  }

  rootfs {
    storage = var.pve.default_storage_pool
    size    = "8G"
  }

  # /var/lib/postgresql
  mountpoint {
    mp        = "/var/lib/postgresql"
    size      = "128G"
    slot      = 0
    key       = 0
    storage   = var.pve.default_storage_pool
    backup    = false
    replicate = false
    shared    = false
  }

  lifecycle {
    ignore_changes = [
      description,
      ostemplate,
      password,
      ssh_public_keys,
      rootfs[0].storage
    ]
  }
}
