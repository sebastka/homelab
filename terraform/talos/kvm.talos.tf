locals {
  current_status = "running" # running | stopped
  talos_image    = "local:iso/nocloud-amd64-secureboot.iso"
  current_image  = local.talos_image

  cp_config     = { mem = 8192,  cores = 4 }
  worker_config = { mem = 24576, cores = 8 }

  talos_nodes = {
    "cp01" = { type = "controlplane", pve_node: "hera", hwaddr = "bc:24:11:10:fe:09", gpu = false }
    "cp02" = { type = "controlplane", pve_node: "hera", hwaddr = "bc:24:11:10:fe:0A", gpu = false }
    "cp03" = { type = "controlplane", pve_node: "hera", hwaddr = "bc:24:11:10:fe:0B", gpu = false }
    "w01"  = { type = "worker",       pve_node: "hera", hwaddr = "bc:24:11:1c:42:be", gpu = true }
    "w02"  = { type = "worker",       pve_node: "hera", hwaddr = "bc:24:11:97:24:5f", gpu = false }
    "w03"  = { type = "worker",       pve_node: "hera", hwaddr = "bc:24:11:02:d7:95", gpu = false }
  }
}

resource "proxmox_vm_qemu" "talos_nodes" {
  for_each = local.talos_nodes

  name               = "${each.key}.${var.pve.domain}"
  description        = each.value.type == "controlplane" ? "Talos Control Plane" : "Talos Worker"
  tags               = "talos,talmox,${each.value.type}"
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
  memory             = each.value.type == "controlplane" ? local.cp_config.mem : local.worker_config.mem
  balloon            = 512
  boot               = "order=ide2;scsi0"

  startup_shutdown {
    shutdown_timeout = 300
    startup_delay    = 60
  }

  cpu {
    cores = each.value.type == "controlplane" ? local.cp_config.cores : local.worker_config.cores
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
      # Root disk
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

      # Additional data disk for worker nodes
      dynamic "scsi1" {
        for_each = each.value.type == "worker" ? [1] : []
        content {
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
