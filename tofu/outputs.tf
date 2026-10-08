output "hosts" {
  description = "All Tofu-managed hosts with their data, keyed by FQDN"
  value       = local.hosts
}
