locals {
  current_status = "running" # running | stopped
  talos_image    = "local:iso/nocloud-amd64-secureboot.iso"
  current_image  = local.talos_image

  talos_nodes = {
    "t01" = { pve_node: "hera", hwaddr = "bc:24:11:10:fe:09", gpu = false }
    "t02" = { pve_node: "hera", hwaddr = "bc:24:11:10:fe:0A", gpu = false }
    "t03" = { pve_node: "hera", hwaddr = "bc:24:11:10:fe:0B", gpu = true }
  }
}

resource "proxmox_vm_qemu" "talos_nodes" {
  for_each = local.talos_nodes

  name               = "${each.key}.${var.pve.domain}"
  description        = "Talos Kubernetes Node"
  tags               = "talos,talmox,controlplane,worker"
  target_nodes       = [each.value.pve_node]
  qemu_os            = "l26"
  machine            = "q35"
  agent              = 1
  agent_timeout      = 30
  skip_ipv6          = true
  bios               = "ovmf"
  start_at_node_boot = true
  vm_state           = local.current_status
  scsihw             = "virtio-scsi-single"
  memory             = 32768
  balloon            = 0
  boot               = "order=ide2;scsi0"

  startup_shutdown {
    shutdown_timeout = 300
    startup_delay    = 60
  }

  cpu {
    cores = 12
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
      # OS Root disk
      scsi0 {
        disk {
          size       = "32G"
          storage    = var.pve.default_storage_pool
          iothread   = true
          emulatessd = true
          backup     = false
          replicate  = false
        }
      }

      # Data disk
      scsi1 {
        disk {
          size       = "128G"
          storage    = var.pve.default_storage_pool
          iothread   = true
          emulatessd = true
          backup     = false
          replicate  = false
        }
      }
    }

    ide {
      ide2 {
        cdrom {
          iso = local.current_image
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
