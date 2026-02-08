locals {
  current_status = "running" # running | stopped
  talos_image    = "local:iso/nocloud-amd64-secureboot.iso"
  current_image  = local.talos_image

  cp_config     = { mem = 8192,  cores = 4 }
  worker_config = { mem = 24576, cores = 8 }

  talos_nodes = {
    "cp01" = { type = "controlplane", pve_node: "hera", nic0_hwaddr = "bc:24:11:10:fe:09", nic1_hwaddr = "BC:24:11:78:E8:85", gpu = false }
    "cp02" = { type = "controlplane", pve_node: "hera", nic0_hwaddr = "bc:24:11:10:fe:0A", nic1_hwaddr = "BC:24:11:FF:24:54", gpu = false }
    "cp03" = { type = "controlplane", pve_node: "hera", nic0_hwaddr = "bc:24:11:10:fe:0B", nic1_hwaddr = "BC:24:11:F7:10:84", gpu = false }
    "w01"  = { type = "worker",       pve_node: "hera", nic0_hwaddr = "bc:24:11:1c:42:be", nic1_hwaddr = "BC:24:11:7F:41:E6", gpu = true }
    "w02"  = { type = "worker",       pve_node: "hera", nic0_hwaddr = "bc:24:11:97:24:5f", nic1_hwaddr = "BC:24:11:D3:CD:22", gpu = false }
    "w03"  = { type = "worker",       pve_node: "hera", nic0_hwaddr = "bc:24:11:02:d7:95", nic1_hwaddr = "BC:24:11:9D:B6:B9", gpu = false }

    # "w04"  = { type = "worker",       nic0_hwaddr = "bc:24:11:02:d7:96", nic1_hwaddr = "XXX", gpu = false }
    # "w05"  = { type = "worker",       nic0_hwaddr = "bc:24:11:02:d7:97", nic1_hwaddr = "XXX", gpu = false }
    # "w06"  = { type = "worker",       nic0_hwaddr = "bc:24:11:02:d7:98", nic1_hwaddr = "XXX", gpu = false }
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
  boot               = "order=scsi0;ide2"

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
    tag     = 100
    model   = "virtio"
    macaddr = each.value.nic0_hwaddr
  }

  network {
    id      = 1
    bridge  = "vmbr0"
    tag     = 200
    model   = "virtio"
    macaddr = each.value.nic1_hwaddr
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
