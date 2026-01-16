resource "proxmox_lxc" "zbx" {
  hostname             = "zbx.${var.pve_host}"
  ostemplate           = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
  description          = "Zabbix server"
  tags                 = "zabbix"
  password             = "changeme"
  target_node          = var.pve_node_name
  arch                 = "amd64"
  console              = true
  cores                = 4
  memory               = 4096
  swap                 = 0
  ignore_unpack_errors = false
  onboot               = true
  startup              = "up=60"
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
    hwaddr   = "BC:24:11:65:71:7A"
    ip       = "dhcp"
  }

  rootfs {
    storage = var.pve_storage_pool
    size    = "8G"
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
