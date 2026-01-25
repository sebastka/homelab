resource "proxmox_vm_qemu" "debian01" {
  clone_id   = 999 # template.hera.home.karlsen.fr
  full_clone = true

  name               = "debian.${var.pve_host}"
  tags               = "debian"
  target_nodes       = [var.pve_node_name]
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
    startup_delay    = 0
  }

  cpu {
    cores = 2
    type  = "host"
    numa  = true
  }

  network {
    id      = 0
    bridge  = "vmbr0"
    model   = "virtio"
    macaddr = "bc:24:11:d5:b8:6f"
  }

  disks {
    scsi {
      # Boot disk
      scsi0 {
        disk {
          size       = "64G"
          storage    = var.pve_storage_pool
          iothread   = true
          emulatessd = true
          backup     = false
          replicate  = false
        }
      }
    }
  }

  vga {
    type   = "virtio"
    memory = 512
  }

  lifecycle {
    ignore_changes = [
      ciuser,
      sshkeys,
      network
    ]
  }
}
