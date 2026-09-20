output "host_data" {
  description = "Per-host data for Ansible inventory"
  value = merge(
    { for k, v in proxmox_virtual_environment_vm.talos_nodes : v.name => {
      vm_id  = v.vm_id
      hwaddr = lower(v.network_device[0].mac_address)
      ip     = var.talos_nodes[k].ip
      node   = var.pve.name
      tags   = v.tags
    } },
    { for k, v in proxmox_virtual_environment_vm.storage_vms : v.name => {
      vm_id  = v.vm_id
      hwaddr = lower(v.network_device[0].mac_address)
      ip     = var.vms[k].network.ip
      iface  = var.vms[k].network.iface
      node   = var.pve.name
      tags   = v.tags
    } },
    { for k, v in proxmox_virtual_environment_vm.windows : v.name => {
      vm_id  = v.vm_id
      hwaddr = lower(v.network_device[0].mac_address)
      ip     = var.vms[k].network.ip
      iface  = var.vms[k].network.iface
      node   = var.pve.name
      tags   = v.tags
    } },
    { for k, v in proxmox_virtual_environment_container.containers_database : v.initialization[0].hostname => {
      vm_id  = v.vm_id
      hwaddr = lower(v.network_interface[0].mac_address)
      ip     = var.containers[k].ip
      node   = var.pve.name
      tags   = v.tags
    } },
    { for k, v in proxmox_virtual_environment_container.containers_distribution : v.initialization[0].hostname => {
      vm_id  = v.vm_id
      hwaddr = lower(v.network_interface[0].mac_address)
      ip     = var.containers[k].ip
      node   = var.pve.name
      tags   = v.tags
    } }
  )
}
