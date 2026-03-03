# Do not manage - Script on Helios updates regularly
# resource "cloudflare_dns_record" "spkagcom_a_root" {
#   content = "XXX"
#   name    = cloudflare_zone.spkagcom.name
#   proxied = false
#   ttl     = 1
#   type    = "A"
#   zone_id = cloudflare_zone.spkagcom.id
# }

resource "cloudflare_dns_record" "spkagcom_caa" {
  name    = cloudflare_zone.spkagcom.name
  proxied = false
  ttl     = 1
  type    = "CAA"
  zone_id = cloudflare_zone.spkagcom.id
  data = {
    flags = 128
    tag   = "issue"
    value = "letsencrypt.org"
  }
}

resource "cloudflare_dns_record" "spkagcom_cname_www" {
  content = cloudflare_zone.spkagcom.name
  name    = "www"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.spkagcom.id
}

resource "cloudflare_dns_record" "spkagcom_mx" {
  content  = var.domeneshop.mx
  name     = cloudflare_zone.spkagcom.name
  priority = 10
  proxied  = false
  ttl      = 1
  type     = "MX"
  zone_id  = cloudflare_zone.spkagcom.id
}

resource "cloudflare_dns_record" "spkagcom_txt_dmarc" {
  content = format(var.domeneshop.dmarc-rua, "mailto:${var.domeneshop.ds-rua},mailto:9d9ec2b190c54675920ea199ad77047e@dmarc-reports.cloudflare.net")
  name    = "_dmarc"
  proxied = false
  ttl     = 3600
  type    = "TXT"
  zone_id = cloudflare_zone.spkagcom.id
}

resource "cloudflare_dns_record" "spkagcom_txt_spf" {
  content = var.domeneshop.spf-ds
  name    = cloudflare_zone.spkagcom.name
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.spkagcom.id
}
