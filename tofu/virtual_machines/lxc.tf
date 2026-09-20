resource "null_resource" "setup_user" {
  for_each = { for k, v in var.containers : k => v if v.setup_user }

  triggers = {
    container_id = try(
      proxmox_virtual_environment_container.containers_database[each.key].id,
      proxmox_virtual_environment_container.containers_distribution[each.key].id,
    )
  }

  connection {
    type  = "ssh"
    host  = var.pve.domain
    user  = "ansible"
    agent = true
  }

  provisioner "remote-exec" {
    inline = concat(
      [
        "sleep 5",
        "sudo pct exec ${each.value.vm_id} -- bash -c 'useradd -m -s /bin/bash sebastian'",
        "sudo pct exec ${each.value.vm_id} -- bash -c \"echo 'sebastian:${var.lxc_passwords.sebastian}' | chpasswd\"",
        "sudo pct exec ${each.value.vm_id} -- bash -c 'mkdir -p /home/sebastian/.ssh && chmod 700 /home/sebastian/.ssh'",
      ],
      [for key in var.ssh_authorized_keys : "sudo pct exec ${each.value.vm_id} -- bash -c \"echo '${key}' >> /home/sebastian/.ssh/authorized_keys\""],
      [
        "sudo pct exec ${each.value.vm_id} -- bash -c 'chmod 600 /home/sebastian/.ssh/authorized_keys && chown -R sebastian:sebastian /home/sebastian/.ssh'",
        "sudo pct exec ${each.value.vm_id} -- bash -c \"printf 'sebastian ALL=(ALL) NOPASSWD: ALL\\n' > /etc/sudoers.d/sebastian\"",
      ]
    )
  }

  depends_on = [
    proxmox_virtual_environment_container.containers_database,
    proxmox_virtual_environment_container.containers_distribution,
  ]
}

resource "null_resource" "zfs_sync_disabled" {
  for_each = var.containers

  triggers = {
    vm_id = each.value.vm_id
  }

  connection {
    type  = "ssh"
    host  = var.pve.domain
    user  = "ansible"
    agent = true
  }

  provisioner "remote-exec" {
    inline = [
      "sudo zfs set sync=disabled rpool/data/subvol-${self.triggers.vm_id}-disk-0",
      "sudo zfs set sync=disabled rpool/data/subvol-${self.triggers.vm_id}-disk-1 || true",
    ]
  }

  depends_on = [
    proxmox_virtual_environment_container.containers_database,
    proxmox_virtual_environment_container.containers_distribution,
  ]
}
