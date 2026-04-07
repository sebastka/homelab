locals {
  debian_vms = {
    # "debian01" = { pve_node: "hera", description = "Debian VM - Stable", start_at_node_boot = false, current_status = "stopped", hwaddr = "bc:24:11:d5:b8:7a", memory = 4096, cores = 2, gpu = false }
    # "debian02" = { pve_node: "hera", description = "Debian VM - Testing", start_at_node_boot = false, current_status = "stopped", hwaddr = "bc:24:11:d5:b8:7b", memory = 4096, cores = 2, gpu = false }
    # "debian03" = { pve_node: "hera", description = "Debian VM - Unstable", start_at_node_boot = false, current_status = "stopped", hwaddr = "bc:24:11:d5:b8:7c", memory = 4096, cores = 2, gpu = false }
  }
}

resource "proxmox_vm_qemu" "debian_vms" {
  for_each = local.debian_vms
  vmid = 120 + tonumber(substr(each.key, -1, 2))

  # clone_id   = 105 # template.hera.home.karlsen.fr
  # full_clone = true

  name               = "${each.key}.${var.pve.domain}"
  description        = "Debian VM"
  tags               = "debian"
  target_nodes       = [each.value.pve_node]
  qemu_os            = "l26"
  machine            = "q35"
  agent              = 1
  agent_timeout      = 30
  skip_ipv6          = true
  bios               = "ovmf"
  start_at_node_boot = each.value.start_at_node_boot
  vm_state           = each.value.current_status # running | stopped
  scsihw             = "virtio-scsi-single"
  memory             = each.value.memory
  balloon            = 0

  startup_shutdown {
    shutdown_timeout = 300
    startup_delay    = 60
  }

  cpu {
    cores = each.value.cores
    type  = "host"
    numa  = true
  }

  network {
    id      = 0
    bridge  = "vmbr0"
    model   = "virtio"
    macaddr = each.value.hwaddr
  }

  # If GPU passthrough is enabled, use "none" VGA, otherwise use "virtio" VGA
  dynamic "vga" {
    for_each = each.value.gpu ? [1] : []
    content {
      type = "none"
    }
  }
  dynamic "vga" {
    for_each = each.value.gpu ? [] : [1]
    content {
      type = "virtio"
      memory = 512
    }
  }

  # GPU passthrough if gpu is enabled for the node
  dynamic "pcis" {
    for_each = each.value.gpu ? [1] : []
    content {
      pci0 {
        mapping {
          mapping_id  = "iGPU"
          pcie        = true
          primary_gpu = true
          rombar      = true
        }
      }
    }
  }

  disks {
    scsi {
      # Boot disk
      scsi0 {
        disk {
          size       = "64G"
          storage    = var.pve.default_storage_pool
          iothread   = true
          emulatessd = true
          backup     = false
          replicate  = false
        }
      }
    }
  }

  efidisk {
    pre_enrolled_keys = false
    efitype           = "4m"
    storage           = var.pve.default_storage_pool
  }

  tpm_state {
    storage = var.pve.default_storage_pool
    version = "v2.0"
  }

  lifecycle {
    ignore_changes = [
      vm_state,
      ciuser,
      sshkeys
    ]
  }
}
