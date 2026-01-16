locals {
  node_names = {
    "docker01" = { mac_address = "bc:24:11:b5:01:3e" }
  }
}

resource "proxmox_vm_qemu" "docker01" {
  for_each = local.node_names

  clone_id   = 999 # templatevm.hera.home.karlsen.fr
  full_clone = true

  name               = "${each.key}.${var.pve_host}"
  tags               = "docker,swarm"
  target_nodes       = [var.pve_node_name]
  qemu_os            = "l26"
  machine            = "q35"
  agent              = 1
  agent_timeout      = 30
  skip_ipv6          = true
  bios               = "ovmf"
  start_at_node_boot = false
  vm_state           = "stopped" # running | stopped
  scsihw             = "virtio-scsi-single"
  memory             = 2048 # 8192
  balloon            = 512
  # boot          = "order=scsi0"

  startup_shutdown {
    shutdown_timeout = 300
    startup_delay    = 60
  }

  cpu {
    cores = 4
    type  = "host"
    numa  = true
  }

  network {
    id      = 0
    bridge  = "vmbr0"
    model   = "virtio"
    macaddr = each.value.mac_address
  }

  disks {
    scsi {
      # Boot disk
      scsi0 {
        disk {
          size       = "32G"
          storage    = var.pve_storage_pool
          iothread   = true
          emulatessd = true
          backup     = false
          replicate  = false
        }
      }

      # /opt/docker data disk
      scsi1 {
        disk {
          size       = "32G"
          storage    = var.pve_storage_pool
          iothread   = true
          emulatessd = true
          backup     = false
          replicate  = false
        }
      }

      # /var/lib/docker disk
      scsi2 {
        disk {
          size       = "32G"
          storage    = var.pve_storage_pool
          iothread   = true
          emulatessd = true
          backup     = false
          replicate  = false
        }
      }

      # /var/lib/containerd disk
      scsi3 {
        disk {
          size       = "32G"
          storage    = var.pve_storage_pool
          iothread   = true
          emulatessd = true
          backup     = false
          replicate  = false
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      ciuser,
      sshkeys,
      network
    ]
  }
}
