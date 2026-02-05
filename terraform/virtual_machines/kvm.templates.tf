resource "proxmox_vm_qemu" "templatevm" {
  # clone_id =
  full_clone = false

  name               = "templatevm.${var.pve.domain}"
  tags               = "template"
  target_nodes       = [var.pve.name]
  qemu_os            = "l26"
  machine            = "q35"
  agent              = 1
  agent_timeout      = 30
  skip_ipv6          = true
  bios               = "ovmf"
  start_at_node_boot = false
  vm_state           = "stopped"
  scsihw             = "virtio-scsi-single"
  memory             = 4096
  balloon            = 512

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
    macaddr = "bc:24:11:85:a7:bf"
  }

  disks {
    scsi {
      # Boot disk
      scsi0 {
        disk {
          size       = "8G"
          storage    = var.pve.default_storage_pool
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
      network,
      vm_state
    ]
  }
}
