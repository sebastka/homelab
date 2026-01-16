variable "local_domain" {
  description = "The domain name for the VM"
  type        = string
  default     = "home.karlsen.fr"
}

variable "pve_node_name" {
  description = "The Proxmox node name"
  type        = string
  default     = "hera"
}

variable "pve_host" {
  description = "The Proxmox host to connect to"
  type        = string
  default     = "hera.home.karlsen.fr"
}

variable "pve_storage_pool" {
  description = "The Proxmox storage pool to use"
  type        = string
  default     = "local-zfs"
}

variable "authorized_keys" {
  description = "SSH public keys to authorize"
  type        = list(string)
  default = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKw42V/vEj+UrBy1zcVKubbdkZEVSjzr1W5yWfX2cjdL sebastian@zeus.home.karlsen.fr",
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPez8beLkvaGA3EK61rE/EeihTlbiGJJTgPUwgBQ3wiB sebastian@boreas.local"
  ]
}
