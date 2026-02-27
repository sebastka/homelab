# Do not manage - Script on Helios updates regularly
# resource "cloudflare_record" "karlsenfr_a_root" {
#   content = "XXX"
#   name    = cloudflare_zone.karlsenfr.zone
#   proxied = false
#   ttl     = 1
#   type    = "A"
#   zone_id = cloudflare_zone.karlsenfr.id
# }

resource "cloudflare_record" "karlsenfr_caa" {
  name    = cloudflare_zone.karlsenfr.zone
  proxied = false
  ttl     = 1
  type    = "CAA"
  zone_id = cloudflare_zone.karlsenfr.id
  data {
    flags = 128
    tag   = "issue"
    value = "letsencrypt.org"
  }
}

resource "cloudflare_record" "karlsenfr_cname_www" {
  content = cloudflare_zone.karlsenfr.zone
  name    = "www"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.karlsenfr.id
}

resource "cloudflare_record" "karlsenfr_cname_git" {
  content = cloudflare_zone.karlsenfr.zone
  name    = "git"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.karlsenfr.id
}

resource "cloudflare_record" "karlsenfr_cname_auth" {
  content = cloudflare_zone.karlsenfr.zone
  name    = "auth"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.karlsenfr.id
}

resource "cloudflare_record" "karlsenfr_cname_matrix" {
  content = cloudflare_zone.karlsenfr.zone
  name    = "matrix"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.karlsenfr.id
}

resource "cloudflare_record" "karlsenfr_mx" {
  content  = var.domeneshop.mx
  name     = cloudflare_zone.karlsenfr.zone
  priority = 10
  proxied  = false
  ttl      = 1
  type     = "MX"
  zone_id  = cloudflare_zone.karlsenfr.id
}

resource "cloudflare_record" "karlsenfr_txt_dmarc" {
  content = format(var.domeneshop.dmarc-rua, "mailto:${var.domeneshop.ds-rua},mailto:4cedcb540e0d4d4f86f0c698addc94c9@dmarc-reports.cloudflare.net")
  name    = "_dmarc"
  proxied = false
  ttl     = 3600
  type    = "TXT"
  zone_id = cloudflare_zone.karlsenfr.id
}

resource "cloudflare_record" "karlsenfr_txt_spf" {
  content = var.domeneshop.spf-ds
  name    = cloudflare_zone.karlsenfr.zone
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.karlsenfr.id
}
