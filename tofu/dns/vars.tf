variable "cloudflare" {
  description = "Cloudflare account"
}

variable "domeneshop" {
  description = "Domeneshop e-mail configuration"
}

variable "secret_zones" {
  description = <<-EOT
    Domain names of the zones we do not publish, keyed by alias.

      a, b, c  Cloudflare-hosted  (records_secret_{a,b,c}.tf)
      d, e     Domeneshop-hosted  (records_secret_{d,e}.tf)

    Only the names are secret; the record sets are plain HCL. Comes from
    secrets.sops.yaml -- see the root module's secrets.tf.
  EOT
  type        = map(string)
  sensitive   = true
}
