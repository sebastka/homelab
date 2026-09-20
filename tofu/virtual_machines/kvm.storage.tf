resource "proxmox_virtual_environment_vm" "storage_vms" {
  for_each = { for k, v in var.vms : k => v if v.role == "storage" }
  vm_id    = each.value.vm_id

  node_name   = var.pve.name
  name        = "${each.key}.${var.pve.domain}"
  description = "File server (NFS, Samba)"
  tags        = concat(["vm", "linux", "fileserver"], each.value.tags)

  machine = each.value.machine
  bios    = each.value.bios
  operating_system { type = "l26" }
  tablet_device   = each.value.tablet_device
  keyboard_layout = "en-us"
  scsi_hardware   = "virtio-scsi-single"
  on_boot         = each.value.on_boot
  started         = false
  boot_order      = ["scsi0", "ide0", "net0"]

  startup {
    order      = each.value.startup.order
    up_delay   = each.value.startup.up_delay
    down_delay = each.value.startup.down_delay
  }

  cpu {
    cores   = each.value.cpu.cores
    sockets = each.value.cpu.sockets
    type    = each.value.cpu.type
    numa    = each.value.cpu.numa
  }

  memory {
    dedicated = each.value.mem
  }

  agent {
    enabled = true
    timeout = "30s"
  }

  network_device {
    bridge      = "vmbr0"
    model       = "virtio"
    mac_address = upper(each.value.network.hwaddr)
    queues      = coalesce(each.value.network.queues, each.value.cpu.cores * each.value.cpu.sockets)
    firewall    = each.value.network.fw != 0
  }

  serial_device {
    device = "socket"
  }

  # vga {}
  # audio_device {}
  # hostpci {}

  disk {
    interface    = "scsi0"
    size         = each.value.osdisk.size
    datastore_id = var.pve.default_storage_pool
    iothread     = true
    ssd          = each.value.osdisk.ssd
    discard      = each.value.osdisk.ssd ? true : null
    cache        = "none"
    backup       = false
    replicate    = false
  }

  dynamic "disk" {
    for_each = each.value.extra_disk
    content {
      interface         = disk.value.interface
      path_in_datastore = disk.value.path_in_datastore
      ssd               = disk.value.ssd
      backup            = disk.value.backup
      replicate         = disk.value.replicate
    }
  }

  cdrom {
    file_id   = ""
    interface = "ide0"
  }

  dynamic "efi_disk" {
    for_each = each.value.efi_disk != null ? [each.value.efi_disk] : []
    content {
      datastore_id      = var.pve.default_storage_pool
      type              = "4m"
      pre_enrolled_keys = efi_disk.value.pre_enrolled_keys
    }
  }

  dynamic "tpm_state" {
    for_each = each.value.tpm != null ? [each.value.tpm] : []
    content {
      datastore_id = var.pve.default_storage_pool
      version      = tpm_state.value.version
    }
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      initialization,
      started,
      cdrom,
      disk # Ignore passthough disk: not supported by the BPG provider
    ]
  }
}
