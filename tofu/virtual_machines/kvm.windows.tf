# Windows XP:
# https://archive.org/details/xppro2020
# https://pve.proxmox.com/wiki/Windows_XP_Guest_Notes
# Gen ISO: genisoimage -o ~/backup.iso -V BACKUP -R -J ~/Documents
# Firefox: Download Firefox 43.0.1, then upgrade.
# Updates:
# - https://nuangel.net/2015/04/every-windows-xp-windows-update-in-one-download/
# - https://support.microsoft.com/en-us/topic/microsoft-security-advisory-4025685-guidance-for-older-platforms-june-13-2017-05151e8a-bd7f-f769-43df-38d2c24f96cd

# NB: Use single socket CPU if Windows XP were to be re-installed.

resource "proxmox_virtual_environment_vm" "windows" {
  for_each = { for k, v in var.vms : k => v if v.role == "windows" }
  vm_id    = each.value.vm_id

  node_name   = var.pve.name
  name        = "${each.key}.${var.pve.domain}"
  description = "Windows VM"
  tags        = concat(["vm", "windows"], each.value.tags)

  machine = each.value.machine
  bios    = each.value.bios
  operating_system { type = "wxp" }
  tablet_device   = each.value.tablet_device
  keyboard_layout = "en-us"
  scsi_hardware   = "virtio-scsi-pci"
  on_boot         = each.value.on_boot
  started         = false
  boot_order      = ["virtio0", "ide0", "net0"]

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

  # agent {
  #   enabled = false
  #   timeout = "30s"
  # }

  network_device {
    bridge      = "vmbr0"
    model       = "virtio"
    mac_address = each.value.network.hwaddr
    queues      = coalesce(each.value.network.queues, each.value.cpu.cores * each.value.cpu.sockets)
    firewall    = each.value.network.fw != 0
  }

  # serial_device {}

  vga {
    type   = each.value.vga.type
    memory = each.value.vga.memory
  }

  audio_device {
    enabled = true
    device  = each.value.audio.device
    driver  = each.value.audio.driver
  }

  # hostpci {}

  disk {
    interface    = "virtio0"
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
      cdrom
    ]
  }
}
