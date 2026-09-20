resource "proxmox_virtual_environment_vm" "talos_nodes" {
  for_each = var.talos_nodes
  vm_id    = each.value.vm_id

  node_name   = var.pve.name
  name        = "${each.key}.${var.pve.domain}"
  description = "Talos Kubernetes Node"
  tags        = concat(["vm", "linux", "talos", each.value.cluster], each.value.tags)

  machine = "q35"
  bios    = "ovmf"
  operating_system { type = "l26" }
  tablet_device   = true
  keyboard_layout = "en-us"
  scsi_hardware   = "virtio-scsi-single"
  on_boot         = true
  started         = true
  boot_order      = ["ide2", "scsi0"]

  startup {
    order      = 3
    up_delay   = 60
    down_delay = 300
  }

  cpu {
    cores   = each.value.cpu
    sockets = 1
    type    = "host"
    numa    = true
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
    mac_address = upper(each.value.hwaddr)
    queues      = each.value.cpu
    firewall    = false
  }

  serial_device {
    device = "socket"
  }

  dynamic "vga" {
    for_each = each.value.gpu != null ? [1] : []
    content {
      type = "none"
    }
  }
  dynamic "vga" {
    for_each = each.value.gpu == null ? [1] : []
    content {
      type   = "virtio"
      memory = 512
    }
  }

  dynamic "hostpci" {
    for_each = each.value.gpu != null ? [each.value.gpu] : []
    content {
      device  = hostpci.value.device
      mapping = hostpci.value.mapping
      pcie    = hostpci.value.pcie
      rombar  = hostpci.value.rombar
    }
  }

  disk {
    interface    = "scsi0"
    size         = each.value.osdisk_size
    datastore_id = var.pve.default_storage_pool
    iothread     = true
    ssd          = var.pve.ssd_storage
    discard      = var.pve.ssd_storage ? "on" : null
    cache        = "none"
    backup       = false
    replicate    = false
  }

  disk {
    interface    = "scsi1"
    size         = each.value.datadisk_size
    datastore_id = var.pve.default_storage_pool
    iothread     = true
    ssd          = var.pve.ssd_storage
    discard      = var.pve.ssd_storage ? "on" : null
    cache        = "none"
    backup       = false
    replicate    = false
  }

  cdrom {
    file_id   = each.value.image
    interface = "ide2"
  }

  efi_disk {
    datastore_id      = var.pve.default_storage_pool
    type              = "4m"
    pre_enrolled_keys = false
  }

  tpm_state {
    datastore_id = var.pve.default_storage_pool
    version      = "v2.0"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      started,
      cdrom,
      initialization
    ]
  }
}

resource "null_resource" "longhorn_zvol_sync_disabled" {
  for_each = var.talos_nodes

  triggers = {
    vm_id = each.value.vm_id
  }

  connection {
    type  = "ssh"
    host  = var.pve.domain
    user  = "ansible"
    agent = true
  }

  provisioner "remote-exec" {
    inline = [
      "sudo zfs set sync=disabled rpool/data/vm-${self.triggers.vm_id}-disk-1",
      "sudo zfs set sync=disabled rpool/data/vm-${self.triggers.vm_id}-disk-2",
    ]
  }

  depends_on = [proxmox_virtual_environment_vm.talos_nodes]
}
