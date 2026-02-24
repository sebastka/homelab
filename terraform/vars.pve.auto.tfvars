pve = {
  name                 = "hera"
  cluster_name         = "homelab"
  domain               = "hera.home.karlsen.fr"
  endpoint             = "https://hera.home.karlsen.fr:8006"
  insecure             = false
  default_storage_pool = "local-zfs"
}

ssh_authorized_keys = [
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKw42V/vEj+UrBy1zcVKubbdkZEVSjzr1W5yWfX2cjdL sebastian@zeus.home.karlsen.fr",
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPez8beLkvaGA3EK61rE/EeihTlbiGJJTgPUwgBQ3wiB sebastian@boreas.local"
]
