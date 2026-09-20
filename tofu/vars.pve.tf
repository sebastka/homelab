variable "pve" {
  description = "Proxmox VE nodes"
  type = map(object({
    name                 = string
    domain               = string
    default_storage_pool = string
    ssd_storage          = bool
  }))
  sensitive = false
}

variable "pve_api_tokens" {
  description = "API tokens per node, keyed by node name"
  type        = map(string)
  sensitive   = true
}

variable "ssh_authorized_keys" {
  description = "SSH public keys"
  default     = []
  type        = list(string)
  sensitive   = false
}

variable "lxc_passwords" {
  description = "Passwords for LXC distribution container accounts"
  sensitive   = true
  type = object({
    root      = string
    sebastian = string
  })
}
