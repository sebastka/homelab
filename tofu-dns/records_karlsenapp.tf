# karlsen.app -- wildcard host for the cluster's HTTP ingress. No mail.

# Apex A record is rewritten hourly by cf-record-update on Helios; unmanaged.
#   A  karlsen.app  ->  <Helios / enp1s0>

resource "cloudflare_dns_record" "karlsenapp_caa" {
  name    = cloudflare_zone.karlsenapp.name
  proxied = false
  ttl     = 1
  type    = "CAA"
  zone_id = cloudflare_zone.karlsenapp.id
  data = {
    flags = 128
    tag   = "issue"
    value = "letsencrypt.org"
  }
}

resource "cloudflare_dns_record" "karlsenapp_cname_wc" {
  content = cloudflare_zone.karlsenapp.name
  name    = "*"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.karlsenapp.id
}

# karlsen.app neither sends nor receives mail. The null MX (RFC 7505) refuses
# delivery at connect time; "-all" below authorises no sender. Subdomains need
# no SPF of their own -- the wildcard CNAME sends their TXT lookups to the apex,
# and a CNAME at "*" could not coexist with a TXT there anyway.
resource "cloudflare_dns_record" "karlsenapp_mx_null" {
  content  = "."
  name     = cloudflare_zone.karlsenapp.name
  priority = 0
  proxied  = false
  ttl      = 1
  type     = "MX"
  zone_id  = cloudflare_zone.karlsenapp.id
}


resource "cloudflare_dns_record" "karlsenapp_txt_dmarc" {
  content = format(var.domeneshop.dmarc-rua, "mailto:b8e3ebfffa7a4245a436159a6ad3d796@dmarc-reports.cloudflare.net")
  name    = "_dmarc"
  proxied = false
  ttl     = 3600
  type    = "TXT"
  zone_id = cloudflare_zone.karlsenapp.id
}

resource "cloudflare_dns_record" "karlsenapp_txt_spf" {
  content = var.domeneshop.spf-empty
  name    = cloudflare_zone.karlsenapp.name
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.karlsenapp.id
}
