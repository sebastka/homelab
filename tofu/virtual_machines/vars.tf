variable "pve" {
  description = "Proxmox VE node configuration"
  type = object({
    name                 = string
    domain               = string
    default_storage_pool = string
    ssd_storage          = bool
  })
}

variable "vms" {
  description = "VMs to manage on this Proxmox node (role: 'windows' | 'storage')"
  default     = {}
  type = map(object({
    role          = string
    vm_id         = number
    mem           = number
    on_boot       = bool
    machine       = optional(string, "q35")
    bios          = optional(string, "ovmf")
    tablet_device = optional(bool, true)
    tags          = optional(list(string), [])
    cpu = object({
      cores   = number
      sockets = number
      type    = string
      numa    = bool
    })
    network = object({
      hwaddr = string
      ip     = string
      iface  = optional(string, "ens18")
      queues = optional(number) # null = default to cpu.cores * cpu.sockets
      fw     = optional(number, 0)
    })
    vga = optional(object({
      type   = string
      memory = number
    }))
    audio = optional(object({
      device = string
      driver = string
    }))
    osdisk = object({
      size = number
      ssd  = bool
    })
    efi_disk = optional(object({
      pre_enrolled_keys = bool
    }))
    tpm = optional(object({
      version = string
    }))
    extra_disk = optional(list(object({
      interface         = string
      path_in_datastore = string
      ssd               = optional(bool, false)
      backup            = optional(bool, false)
      replicate         = optional(bool, false)
    })), [])
    startup = optional(object({
      order      = optional(number, 0)
      up_delay   = optional(number, 0)
      down_delay = optional(number, 0)
    }), {})
  }))
}

variable "ssh_authorized_keys" {
  description = "SSH public keys"
  default     = []
  type        = list(string)
}

variable "lxc_passwords" {
  description = "Passwords for LXC distribution container accounts"
  sensitive   = true
  type = object({
    root      = string
    sebastian = string
  })
}

variable "containers" {
  description = "LXC containers to manage on this Proxmox node"
  default     = {}
  type = map(object({
    role        = string
    vm_id       = number
    description = string
    tags        = list(string)
    cores       = number
    cpu_units   = optional(number, 2048)
    mem         = number
    hwaddr      = string
    ip          = string
    rootfs_size = number
    setup_user  = optional(bool, true)
    mountpoint = optional(object({
      path = string
      size = string
    }))
    os = optional(object({
      type             = string
      template_file_id = string
    }))
  }))
}

variable "talos_nodes" {
  description = "Talos nodes to create on this Proxmox node"
  default     = {}
  type = map(object({
    cluster       = string
    vm_id         = number
    cpu           = number
    mem           = number
    tags          = optional(list(string), [])
    osdisk_size   = number
    datadisk_size = number
    hwaddr        = string
    ip            = string
    gpu = optional(object({
      device  = string
      mapping = string
      pcie    = bool
      rombar  = bool
    }))
    image = string
  }))
}
