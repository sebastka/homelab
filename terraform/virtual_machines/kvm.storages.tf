resource "proxmox_vm_qemu" "file01" {
  clone_id   = 105 # template.hera.home.karlsen.fr
  full_clone = true

  name               = "file01.${var.pve.domain}"
  tags               = "fileserver,nfs,samba"
  target_nodes       = [var.pve.name]
  qemu_os            = "l26"
  machine            = "q35"
  agent              = 1
  agent_timeout      = 30
  skip_ipv6          = true
  bios               = "ovmf"
  start_at_node_boot = true
  vm_state           = "running"
  scsihw             = "virtio-scsi-single"
  memory             = 8192
  balloon            = 1024

  startup_shutdown {
    shutdown_timeout = 300
    startup_delay    = 0
  }

  cpu {
    cores = 4
    type  = "host"
    numa  = true
  }

  network {
    id      = 0
    bridge  = "vmbr0"
    tag     = 100
    model   = "virtio"
    macaddr = "bc:24:11:82:e0:a3"
  }

  disks {
    scsi {
      # Boot disk
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

      # Samsung 4 TB nvme for nfs shares
      # Cannot be deleted without being root
      scsi1 {
        passthrough {
          backup     = false
          emulatessd = true
          replicate  = false
          file       = "/dev/disk/by-id/nvme-Samsung_SSD_9100_PRO_4TB_S7Y9NJ0Y510069V"
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      ciuser,
      sshkeys,
      vm_state
    ]
  }
}
