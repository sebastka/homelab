# Apex A record is rewritten hourly by cf-record-update on Helios; unmanaged.

resource "cloudflare_dns_record" "bwdbinfo_caa" {
  name    = cloudflare_zone.bwdbinfo.name
  proxied = false
  ttl     = 1
  type    = "CAA"
  zone_id = cloudflare_zone.bwdbinfo.id
  data = {
    flags = 128
    tag   = "issue"
    value = "letsencrypt.org"
  }
}

resource "cloudflare_dns_record" "bwdbinfo_cname_www" {
  content = cloudflare_zone.bwdbinfo.name
  name    = "www"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.bwdbinfo.id
}

# Null MX (RFC 7505): this domain accepts no mail. A sender fails immediately
# instead of timing out against a host that was never going to answer.
resource "cloudflare_dns_record" "bwdbinfo_mx_null" {
  content  = "."
  name     = cloudflare_zone.bwdbinfo.name
  priority = 0
  proxied  = false
  ttl      = 1
  type     = "MX"
  zone_id  = cloudflare_zone.bwdbinfo.id
}

resource "cloudflare_dns_record" "bwdbinfo_txt_spf" {
  content = var.domeneshop.spf-empty
  name    = cloudflare_zone.bwdbinfo.name
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.bwdbinfo.id
}

# The apex record only covers the apex. Without this, a forged envelope sender
# at any subdomain gets an SPF result of "none" rather than "fail", and only
# DMARC stops it -- so receivers that check SPF but not DMARC would let it by.
resource "cloudflare_dns_record" "bwdbinfo_txt_spf_wc" {
  content = var.domeneshop.spf-empty
  name    = "*"
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.bwdbinfo.id
}

# rua goes to Cloudflare only; the Domeneshop address went with the mailboxes.
resource "cloudflare_dns_record" "bwdbinfo_txt_dmarc" {
  content = format(var.domeneshop.dmarc-rua, "mailto:fe220f49f8c040a1a1c01a44b17a2d54@dmarc-reports.cloudflare.net")
  name    = "_dmarc"
  proxied = false
  ttl     = 3600
  type    = "TXT"
  zone_id = cloudflare_zone.bwdbinfo.id
}
