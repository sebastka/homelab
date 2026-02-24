variable "cloudflare" {
  description = "Cloudflare account"
  sensitive   = false
  type = object({
    account_id = string
  })
}
