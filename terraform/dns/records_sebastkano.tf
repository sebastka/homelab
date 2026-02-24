# Do not manage - Script on Helios updates regularly
# resource "cloudflare_record" "sebastkano_a_root" {
#   content = "XXX"
#   name    = cloudflare_zone.sebastkano.zone
#   proxied = false
#   ttl     = 1
#   type    = "A"
#   zone_id = cloudflare_zone.sebastkano.id
# }

resource "cloudflare_record" "sebastkano_caa" {
  name    = cloudflare_zone.sebastkano.zone
  proxied = false
  ttl     = 1
  type    = "CAA"
  zone_id = cloudflare_zone.sebastkano.id
  data {
    flags = 128
    tag   = "issue"
    value = "letsencrypt.org"
  }
}

resource "cloudflare_record" "sebastkano_cname_www" {
  content = cloudflare_zone.sebastkano.zone
  name    = "www"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.sebastkano.id
}

resource "cloudflare_record" "sebastkano_mx" {
  content  = var.domeneshop.mx
  name     = cloudflare_zone.sebastkano.zone
  priority = 10
  proxied  = false
  ttl      = 1
  type     = "MX"
  zone_id  = cloudflare_zone.sebastkano.id
}

resource "cloudflare_record" "sebastkano_txt_dmarc" {
  content = format(var.domeneshop.dmarc-rua, "mailto:${var.domeneshop.ds-rua},mailto:6b5eb183eee8455aae304f8ccd3e05b6@dmarc-reports.cloudflare.net")
  name    = "_dmarc"
  proxied = false
  ttl     = 3600
  type    = "TXT"
  zone_id = cloudflare_zone.sebastkano.id
}

resource "cloudflare_record" "sebastkano_txt_spf" {
  content = var.domeneshop.spf-ds
  name    = cloudflare_zone.sebastkano.zone
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.sebastkano.id
}
