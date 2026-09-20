# karlsen.org -- mail only, on Domeneshop.

# Apex A record is rewritten hourly by cf-record-update on Helios; unmanaged.
#   A  karlsen.org  ->  <Helios / enp1s0>

resource "cloudflare_dns_record" "karlsenorg_caa" {
  name    = cloudflare_zone.karlsenorg.name
  proxied = false
  ttl     = 1
  type    = "CAA"
  zone_id = cloudflare_zone.karlsenorg.id
  data = {
    flags = 128
    tag   = "issue"
    value = "letsencrypt.org"
  }
}

# Unlike karlsen.fr, autoconfig points straight at Domeneshop here.
resource "cloudflare_dns_record" "karlsenorg_cname_autoconfig" {
  content = var.domeneshop.autoconfig
  name    = "autoconfig"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.karlsenorg.id
}

# Policy host for the _mta-sts TXT below; served by the homepage nginx, which
# hands out the same policy document as karlsen.fr.
resource "cloudflare_dns_record" "karlsenorg_cname_mta-sts" {
  content = cloudflare_zone.karlsenorg.name
  name    = "mta-sts"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.karlsenorg.id
}

resource "cloudflare_dns_record" "karlsenorg_cname_www" {
  content = cloudflare_zone.karlsenorg.name
  name    = "www"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.karlsenorg.id
}

resource "cloudflare_dns_record" "karlsenorg_mx" {
  content  = var.domeneshop.mx
  name     = cloudflare_zone.karlsenorg.name
  priority = 10
  proxied  = false
  ttl      = 1
  type     = "MX"
  zone_id  = cloudflare_zone.karlsenorg.id
}

resource "cloudflare_dns_record" "karlsenorg_srv_autodiscover" {
  name     = "_autodiscover._tcp"
  priority = 0
  proxied  = false
  ttl      = 3600
  type     = "SRV"
  zone_id  = cloudflare_zone.karlsenorg.id
  data = {
    priority = 0
    weight   = 0
    port     = 443
    target   = var.domeneshop.autoconfig
  }
}

resource "cloudflare_dns_record" "karlsenorg_srv_caldavs" {
  name     = "_caldavs._tcp"
  priority = 0
  proxied  = false
  ttl      = 3600
  type     = "SRV"
  zone_id  = cloudflare_zone.karlsenorg.id
  data = {
    priority = 0
    weight   = 0
    port     = 443
    target   = var.domeneshop.caldav
  }
}

resource "cloudflare_dns_record" "karlsenorg_srv_carddavs" {
  name     = "_carddavs._tcp"
  priority = 0
  proxied  = false
  ttl      = 3600
  type     = "SRV"
  zone_id  = cloudflare_zone.karlsenorg.id
  data = {
    priority = 0
    weight   = 0
    port     = 443
    target   = var.domeneshop.carddav
  }
}

resource "cloudflare_dns_record" "karlsenorg_txt_caldavs" {
  content = var.domeneshop.dav-path
  name    = "_caldavs._tcp"
  proxied = false
  ttl     = 3600
  type    = "TXT"
  zone_id = cloudflare_zone.karlsenorg.id
}

resource "cloudflare_dns_record" "karlsenorg_txt_carddavs" {
  content = var.domeneshop.dav-path
  name    = "_carddavs._tcp"
  proxied = false
  ttl     = 3600
  type    = "TXT"
  zone_id = cloudflare_zone.karlsenorg.id
}

resource "cloudflare_dns_record" "karlsenorg_txt_dmarc" {
  content = format(var.domeneshop.dmarc-rua, "mailto:${var.domeneshop.ds-rua},mailto:0ec711df3fa54706adb5dbf1610dc1eb@dmarc-reports.cloudflare.net")
  name    = "_dmarc"
  proxied = false
  ttl     = 3600
  type    = "TXT"
  zone_id = cloudflare_zone.karlsenorg.id
}

# Bump the id whenever the policy document changes, or senders keep the cached
# copy until max_age expires.
resource "cloudflare_dns_record" "karlsenorg_txt_mta-sts" {
  content = "v=STSv1; id=1789935207;"
  name    = "_mta-sts"
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.karlsenorg.id
}

# Same-domain rua on purpose: an address outside the policy domain would need
# an authorisation record at <policy-domain>._report._smtp._tls.<rua-domain>
# (RFC 8460 s3). Needs tlsrpt@karlsen.org to exist at Domeneshop.
resource "cloudflare_dns_record" "karlsenorg_txt_tls_smtp" {
  content = "v=TLSRPTv1; rua=mailto:tlsrpt@${cloudflare_zone.karlsenorg.name}"
  name    = "_smtp._tls"
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.karlsenorg.id
}

resource "cloudflare_dns_record" "karlsenorg_txt_spf" {
  content = var.domeneshop.spf-ds
  name    = cloudflare_zone.karlsenorg.name
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.karlsenorg.id
}

# The apex record only covers the apex. Without this, a forged envelope sender
# at any subdomain gets an SPF result of "none" rather than "fail", and only
# DMARC stops it. No wildcard CNAME here to conflict with.
resource "cloudflare_dns_record" "karlsenorg_txt_spf_wc" {
  content = var.domeneshop.spf-ds
  name    = "*"
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.karlsenorg.id
}
