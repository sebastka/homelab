variable "cloudflare" {
  description = "Cloudflare account"
  sensitive   = true
  type = object({
    account_id = string
    api_token  = string
  })
}
