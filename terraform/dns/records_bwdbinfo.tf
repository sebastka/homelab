# Do not manage - Script on Helios updates regularly
# resource "cloudflare_dns_record" "bwdbinfo_a_root" {
#   content = "XXX"
#   name    = cloudflare_zone.bwdbinfo.name
#   proxied = false
#   ttl     = 1
#   type    = "A"
#   zone_id = cloudflare_zone.bwdbinfo.id
# }

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

resource "cloudflare_dns_record" "bwdbinfo_mx" {
  content  = var.domeneshop.mx
  name     = cloudflare_zone.bwdbinfo.name
  priority = 10
  proxied  = false
  ttl      = 1
  type     = "MX"
  zone_id  = cloudflare_zone.bwdbinfo.id
}

resource "cloudflare_dns_record" "bwdbinfo_txt_dmarc" {
  content = format(var.domeneshop.dmarc-rua, "mailto:${var.domeneshop.ds-rua},mailto:fe220f49f8c040a1a1c01a44b17a2d54@dmarc-reports.cloudflare.net")
  name    = "_dmarc"
  proxied = false
  ttl     = 3600
  type    = "TXT"
  zone_id = cloudflare_zone.bwdbinfo.id
}

resource "cloudflare_dns_record" "bwdbinfo_txt_spf" {
  content = var.domeneshop.spf-ds
  name    = cloudflare_zone.bwdbinfo.name
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.bwdbinfo.id
}