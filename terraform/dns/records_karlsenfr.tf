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

resource "cloudflare_dns_record" "karlsenfr_cname_openpgpkey" {
  content = cloudflare_zone.karlsenfr.name
  name    = "openpgpkey"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.karlsenfr.id
}

resource "cloudflare_dns_record" "karlsenfr_cname_ldap" {
  content = cloudflare_zone.karlsenfr.name
  name    = "ldap"
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

# resource "cloudflare_dns_record" "karlsenfr_srv_tcp_turn" {
#   name    = "_turn._tcp"
#   proxied = false
#   ttl     = 1
#   type    = "SRV"
#   zone_id = cloudflare_zone.karlsenfr.id

#   priority = 10
#   data = {
#     service  = "_turn"
#     proto    = "_tcp"
#     name     = cloudflare_zone.karlsenfr.name
#     priority = 10
#     weight   = 5
#     port     = 5349
#     target   = "turn.karlsen.fr"
#   }
# }

# resource "cloudflare_dns_record" "karlsenfr_srv_udp_turn" {
#   name    = "_turn._udp"
#   proxied = false
#   ttl     = 1
#   type    = "SRV"
#   zone_id = cloudflare_zone.karlsenfr.id

#   priority = 10
#   data = {
#     service  = "_turn"
#     proto    = "_udp"
#     name     = cloudflare_zone.karlsenfr.name
#     priority = 10
#     weight   = 5
#     port     = 3478
#     target   = "turn.karlsen.fr"
#   }
# }

# resource "cloudflare_dns_record" "karlsenfr_srv_tcp_stun" {
#   name    = "_stun._tcp"
#   proxied = false
#   ttl     = 1
#   type    = "SRV"
#   zone_id = cloudflare_zone.karlsenfr.id

#   priority = 10
#   data = {
#     service  = "_stun"
#     proto    = "_tcp"
#     name     = cloudflare_zone.karlsenfr.name
#     priority = 10
#     weight   = 5
#     port     = 3478
#     target   = "turn.karlsen.fr"
#   }
# }

# resource "cloudflare_dns_record" "karlsenfr_srv_udp_stun" {
#   name    = "_stun._udp"
#   proxied = false
#   ttl     = 1
#   type    = "SRV"
#   zone_id = cloudflare_zone.karlsenfr.id

#   priority = 10
#   data = {
#     service  = "_stun"
#     proto    = "_udp"
#     name     = cloudflare_zone.karlsenfr.name
#     priority = 10
#     weight   = 5
#     port     = 3478
#     target   = "turn.karlsen.fr"
#   }
# }

# resource "cloudflare_dns_record" "karlsenfr_srv_tcp_matrix" {
#   name    = "_matrix._tcp"
#   proxied = false
#   ttl     = 1
#   type    = "SRV"
#   zone_id = cloudflare_zone.karlsenfr.id

#   priority = 10
#   data = {
#     service  = "_matrix"
#     proto    = "_tcp"
#     name     = cloudflare_zone.karlsenfr.name
#     priority = 10
#     weight   = 1
#     port     = 443
#     target   = "matrix.karlsen.fr"
#   }
# }

resource "cloudflare_dns_record" "karlsenfr_openpgpkey_sebastian" {
  content = "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"
  name    = "4dd68e2ab3a30973318ea903e088b3d3480655ef4236109fe47272c1._openpgpkey"
  proxied = false
  ttl     = 1
  type    = "OPENPGPKEY"
  zone_id = cloudflare_zone.karlsenfr.id
}
