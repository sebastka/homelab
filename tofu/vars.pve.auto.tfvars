pve = {
  atlas = {
    name                 = "atlas"
    domain               = "atlas.home.karlsen.fr"
    default_storage_pool = "local-zfs"
    ssd_storage          = false
  }
  hera = {
    name                 = "hera"
    domain               = "hera.home.karlsen.fr"
    default_storage_pool = "local-zfs"
    ssd_storage          = true
  }
}

ssh_authorized_keys = [
  "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIMf9bldc1/uS+kAo4WGX1CW6ex0ewLP0P1v+9/+QItJcAAAABHNzaDo= sebastian@karlsen.fr",
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKw42V/vEj+UrBy1zcVKubbdkZEVSjzr1W5yWfX2cjdL sebastian@zeus.home.karlsen.fr",
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPez8beLkvaGA3EK61rE/EeihTlbiGJJTgPUwgBQ3wiB sebastian@boreas.local"
]
