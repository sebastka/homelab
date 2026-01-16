resource "proxmox_lxc" "db01" {
  hostname             = "db01.${var.pve_host}"
  ostemplate           = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
  description          = "Database server (MariaDB)"
  tags                 = "database,db,mariadb"
  password             = "changeme"
  target_node          = var.pve_node_name
  arch                 = "amd64"
  console              = true
  cores                = 4
  memory               = 4096
  swap                 = 0
  ignore_unpack_errors = false
  onboot               = true
  startup              = "up=10"
  start                = true
  ssh_public_keys      = join("\n", var.authorized_keys)
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
    storage = var.pve_storage_pool
    size    = "8G"
  }

  # /var/lib/mysql
  mountpoint {
    mp        = "/var/lib/mysql"
    size      = "128G"
    slot      = 0
    key       = 0
    storage   = var.pve_storage_pool
    backup    = false
    replicate = false
    shared    = false
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

resource "proxmox_lxc" "db02" {
  hostname             = "db02.${var.pve_host}"
  ostemplate           = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
  description          = "Database server (PostgreSQL)"
  tags                 = "database,db,postgresql,postgres"
  password             = "changeme"
  target_node          = var.pve_node_name
  arch                 = "amd64"
  console              = true
  cores                = 4
  memory               = 4096
  swap                 = 0
  ignore_unpack_errors = false
  onboot               = true
  startup              = "up=10"
  start                = true
  ssh_public_keys      = join("\n", var.authorized_keys)
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
    storage = var.pve_storage_pool
    size    = "8G"
  }

  # /var/lib/postgresql
  mountpoint {
    mp        = "/var/lib/postgresql"
    size      = "128G"
    slot      = 0
    key       = 0
    storage   = var.pve_storage_pool
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

resource "proxmox_lxc" "db03" {
  hostname             = "db03.${var.pve_host}"
  ostemplate           = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
  description          = "Database server (MongoDB)"
  tags                 = "database,db,mongodb,mongo"
  password             = "changeme"
  target_node          = var.pve_node_name
  arch                 = "amd64"
  console              = true
  cores                = 4
  memory               = 4096
  swap                 = 0
  ignore_unpack_errors = false
  onboot               = true
  startup              = "up=10"
  start                = true
  ssh_public_keys      = join("\n", var.authorized_keys)
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
    hwaddr   = "BC:24:11:F5:DB:11"
    ip       = "dhcp"
  }

  rootfs {
    storage = var.pve_storage_pool
    size    = "8G"
  }

  # /var/lib/mongodb
  mountpoint {
    mp        = "/var/lib/mongodb"
    size      = "128G"
    slot      = 0
    key       = 0
    storage   = var.pve_storage_pool
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
