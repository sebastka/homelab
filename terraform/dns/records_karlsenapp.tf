# Do not manage - Script on Helios updates regularly
# resource "cloudflare_record" "karlsenapp_a_root" {
#   content = "XXX"
#   name    = cloudflare_zone.karlsenapp.zone
#   proxied = false
#   ttl     = 1
#   type    = "A"
#   zone_id = cloudflare_zone.karlsenapp.id
# }

resource "cloudflare_record" "karlsenapp_caa" {
  name    = cloudflare_zone.karlsenapp.zone
  proxied = false
  ttl     = 1
  type    = "CAA"
  zone_id = cloudflare_zone.karlsenapp.id
  data {
    flags = 128
    tag   = "issue"
    value = "letsencrypt.org"
  }
}

resource "cloudflare_record" "karlsenapp_cname_wc" {
  content = cloudflare_zone.karlsenapp.zone
  name    = "*"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.karlsenapp.id
}

# No MX on karlsen.app
# resource "cloudflare_record" "karlsenapp_mx" {
#   content  = var.domeneshop.mx
#   name     = cloudflare_zone.karlsenapp.zone
#   priority = 10
#   proxied  = false
#   ttl      = 1
#   type     = "MX"
#   zone_id  = cloudflare_zone.karlsenapp.id
# }

resource "cloudflare_record" "karlsenapp_txt_dmarc" {
  content = format(var.domeneshop.dmarc-rua, "mailto:b8e3ebfffa7a4245a436159a6ad3d796@dmarc-reports.cloudflare.net")
  name    = "_dmarc"
  proxied = false
  ttl     = 3600
  type    = "TXT"
  zone_id = cloudflare_zone.karlsenapp.id
}

resource "cloudflare_record" "karlsenapp_txt_spf" {
  content = var.domeneshop.spf-empty
  name    = cloudflare_zone.karlsenapp.zone
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.karlsenapp.id
}
