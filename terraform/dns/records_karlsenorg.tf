# Do not manage - Script on Helios updates regularly
# resource "cloudflare_record" "karlsenorg_a_root" {
#   content = "XXX"
#   name    = cloudflare_zone.karlsenorg.zone
#   proxied = false
#   ttl     = 1
#   type    = "A"
#   zone_id = cloudflare_zone.karlsenorg.id
# }

resource "cloudflare_record" "karlsenorg_caa" {
  name    = cloudflare_zone.karlsenorg.zone
  proxied = false
  ttl     = 1
  type    = "CAA"
  zone_id = cloudflare_zone.karlsenorg.id
  data {
    flags = 128
    tag   = "issue"
    value = "letsencrypt.org"
  }
}

resource "cloudflare_record" "karlsenorg_cname_www" {
  content = cloudflare_zone.karlsenorg.zone
  name    = "www"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.karlsenorg.id
}

resource "cloudflare_record" "karlsenorg_mx" {
  content  = var.domeneshop.mx
  name     = cloudflare_zone.karlsenorg.zone
  priority = 10
  proxied  = false
  ttl      = 1
  type     = "MX"
  zone_id  = cloudflare_zone.karlsenorg.id
}

resource "cloudflare_record" "karlsenorg_txt_dmarc" {
  content = format(var.domeneshop.dmarc-rua, "mailto:${var.domeneshop.ds-rua},mailto:0ec711df3fa54706adb5dbf1610dc1eb@dmarc-reports.cloudflare.net")
  name    = "_dmarc"
  proxied = false
  ttl     = 3600
  type    = "TXT"
  zone_id = cloudflare_zone.karlsenorg.id
}

resource "cloudflare_record" "karlsenorg_txt_spf" {
  content = var.domeneshop.spf-ds
  name    = cloudflare_zone.karlsenorg.zone
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.karlsenorg.id
}
