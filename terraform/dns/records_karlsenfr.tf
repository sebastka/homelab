# Do not manage - Script on Helios updates regularly
# resource "cloudflare_dns_record" "karlsenfr_a_root" {
#   content = "XXX"
#   name    = cloudflare_zone.karlsenfr.name
#   proxied = false
#   ttl     = 1
#   type    = "A"
#   zone_id = cloudflare_zone.karlsenfr.id
# }

resource "cloudflare_dns_record" "karlsenfr_caa" {
  name    = cloudflare_zone.karlsenfr.name
  proxied = false
  ttl     = 1
  type    = "CAA"
  zone_id = cloudflare_zone.karlsenfr.id
  data = {
    flags = 128
    tag   = "issue"
    value = "letsencrypt.org"
  }
}

resource "cloudflare_dns_record" "karlsenfr_cname_www" {
  content = cloudflare_zone.karlsenfr.name
  name    = "www"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.karlsenfr.id
}

resource "cloudflare_dns_record" "karlsenfr_cname_git" {
  content = cloudflare_zone.karlsenfr.name
  name    = "git"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.karlsenfr.id
}

resource "cloudflare_dns_record" "karlsenfr_cname_auth" {
  content = cloudflare_zone.karlsenfr.name
  name    = "auth"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.karlsenfr.id
}

resource "cloudflare_dns_record" "karlsenfr_cname_matrix" {
  content = cloudflare_zone.karlsenfr.name
  name    = "matrix"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.karlsenfr.id
}

resource "cloudflare_dns_record" "karlsenfr_mx" {
  content  = var.domeneshop.mx
  name     = cloudflare_zone.karlsenfr.name
  priority = 10
  proxied  = false
  ttl      = 1
  type     = "MX"
  zone_id  = cloudflare_zone.karlsenfr.id
}

resource "cloudflare_dns_record" "karlsenfr_txt_dmarc" {
  content = format(var.domeneshop.dmarc-rua, "mailto:${var.domeneshop.ds-rua},mailto:4cedcb540e0d4d4f86f0c698addc94c9@dmarc-reports.cloudflare.net")
  name    = "_dmarc"
  proxied = false
  ttl     = 3600
  type    = "TXT"
  zone_id = cloudflare_zone.karlsenfr.id
}

resource "cloudflare_dns_record" "karlsenfr_txt_spf" {
  content = var.domeneshop.spf-ds
  name    = cloudflare_zone.karlsenfr.name
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.karlsenfr.id
}

resource "cloudflare_dns_record" "karlsenfr_srv_tcp_turn" {
  name    = "_turn._tcp"
  proxied = false
  ttl     = 1
  type    = "SRV"
  zone_id = cloudflare_zone.karlsenfr.id

  priority = 10
  data = {
    service  = "_turn"
    proto    = "_tcp"
    name     = cloudflare_zone.karlsenfr.name
    priority = 10
    weight   = 5
    port     = 5349
    target   = "turn.karlsen.fr"
  }
}

resource "cloudflare_dns_record" "karlsenfr_srv_udp_turn" {
  name    = "_turn._udp"
  proxied = false
  ttl     = 1
  type    = "SRV"
  zone_id = cloudflare_zone.karlsenfr.id

  priority = 10
  data = {
    service  = "_turn"
    proto    = "_udp"
    name     = cloudflare_zone.karlsenfr.name
    priority = 10
    weight   = 5
    port     = 3478
    target   = "turn.karlsen.fr"
  }
}

resource "cloudflare_dns_record" "karlsenfr_srv_tcp_stun" {
  name    = "_stun._tcp"
  proxied = false
  ttl     = 1
  type    = "SRV"
  zone_id = cloudflare_zone.karlsenfr.id

  priority = 10
  data = {
    service  = "_stun"
    proto    = "_tcp"
    name     = cloudflare_zone.karlsenfr.name
    priority = 10
    weight   = 5
    port     = 3478
    target   = "turn.karlsen.fr"
  }
}

resource "cloudflare_dns_record" "karlsenfr_srv_udp_stun" {
  name    = "_stun._udp"
  proxied = false
  ttl     = 1
  type    = "SRV"
  zone_id = cloudflare_zone.karlsenfr.id

  priority = 10
  data = {
    service  = "_stun"
    proto    = "_udp"
    name     = cloudflare_zone.karlsenfr.name
    priority = 10
    weight   = 5
    port     = 3478
    target   = "turn.karlsen.fr"
  }
}

resource "cloudflare_dns_record" "karlsenfr_srv_tcp_matrix" {
  name    = "_matrix._tcp"
  proxied = false
  ttl     = 1
  type    = "SRV"
  zone_id = cloudflare_zone.karlsenfr.id

  priority = 10
  data = {
    service  = "_matrix"
    proto    = "_tcp"
    name     = cloudflare_zone.karlsenfr.name
    priority = 10
    weight   = 1
    port     = 443
    target   = "matrix.karlsen.fr"
  }
}
