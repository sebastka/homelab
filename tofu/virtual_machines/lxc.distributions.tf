# /var/lib/vz/template/cache/archlinux-base_20260420-1_amd64.tar.zst
resource "proxmox_virtual_environment_container" "containers_distribution" {
  for_each = { for k, v in var.containers : k => v if v.role == "distribution" }
  vm_id    = each.value.vm_id

  node_name   = var.pve.name
  description = each.value.description
  tags        = concat(["lxc", "linux", "distribution"], each.value.tags)

  started               = true
  unprivileged          = true
  environment_variables = {}

  initialization {
    hostname = "${each.key}.${var.pve.domain}"

    user_account {
      keys     = var.ssh_authorized_keys
      password = var.lxc_passwords.root
    }
  }

  startup {
    order      = 0
    up_delay   = 0
    down_delay = 0
  }

  cpu {
    cores = each.value.cores
    units = each.value.cpu_units
  }

  memory {
    dedicated = each.value.mem
    swap      = 0
  }

  console {
    enabled   = true
    type      = "tty"
    tty_count = 2
  }

  features {
    nesting = true
    mount   = []
  }

  operating_system {
    template_file_id = each.value.os.template_file_id
    type             = each.value.os.type
  }

  network_interface {
    name        = "eth0"
    bridge      = "vmbr0"
    firewall    = true
    mac_address = upper(each.value.hwaddr)
  }

  disk {
    datastore_id = var.pve.default_storage_pool
    size         = each.value.rootfs_size
  }

  dynamic "mount_point" {
    for_each = each.value.mountpoint != null ? [each.value.mountpoint] : []
    content {
      volume        = var.pve.default_storage_pool
      path          = mount_point.value.path
      size          = mount_point.value.size
      mount_options = []
      backup        = false
      replicate     = false
    }
  }

  lifecycle {
    # prevent_destroy = true
    ignore_changes = [
      started,
      initialization,
      operating_system
    ]
  }
}

