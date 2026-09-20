output "hosts" {
  description = "All Tofu-managed hosts with their data, keyed by FQDN"
  value = merge(
    # module.virtual_machines_atlas.host_data,
    module.virtual_machines_hera.host_data,
  )
}
