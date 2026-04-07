resource "proxmox_vm_qemu" "nixos" {
  # clone_id =
  full_clone = false

  name               = "nixos.${var.pve.domain}"
  description        = "NixOS test VM"
  tags               = "nixos"
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
  memory             = 6096
  balloon            = 0

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
    macaddr = "bc:24:11:97:51:ab"
  }

  vga {
    type   = "virtio"
    memory = 512
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

    ide {
      ide2 {
        cdrom {
          iso = "" # "local:iso/latest-nixos-graphical-x86_64-linux.iso"
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
