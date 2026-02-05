variable "pve" {
  description = "Proxmox VE API connection details"
  type = object({
    name                 = string
    cluster_name         = string
    domain               = string
    endpoint             = string
    insecure             = bool
    default_storage_pool = string
  })
}

variable "ssh_authorized_keys" {
  description = "SSH public keys to authorize"
  type        = list(string)
}
