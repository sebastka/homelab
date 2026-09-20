# Secret zone "c" -- name lives in secrets.sops.yaml, records are public.
#
# Cloudflare-hosted, mail on Domeneshop.
# Apex A record is rewritten hourly by cf-record-update on Helios; unmanaged.

resource "cloudflare_dns_record" "secret_c_caa" {
  name    = cloudflare_zone.secret_c.name
  proxied = false
  ttl     = 1
  type    = "CAA"
  zone_id = cloudflare_zone.secret_c.id
  data = {
    flags = 128
    tag   = "issue"
    value = "letsencrypt.org"
  }
}

resource "cloudflare_dns_record" "secret_c_cname_autoconfig" {
  content = var.domeneshop.autoconfig
  name    = "autoconfig"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.secret_c.id
}

resource "cloudflare_dns_record" "secret_c_cname_www" {
  content = cloudflare_zone.secret_c.name
  name    = "www"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.secret_c.id
}

resource "cloudflare_dns_record" "secret_c_mx" {
  content  = var.domeneshop.mx
  name     = cloudflare_zone.secret_c.name
  priority = 10
  proxied  = false
  ttl      = 1
  type     = "MX"
  zone_id  = cloudflare_zone.secret_c.id
}

resource "cloudflare_dns_record" "secret_c_srv_autodiscover" {
  name     = "_autodiscover._tcp"
  priority = 0
  proxied  = false
  ttl      = 3600
  type     = "SRV"
  zone_id  = cloudflare_zone.secret_c.id
  data = {
    priority = 0
    weight   = 0
    port     = 443
    target   = var.domeneshop.autoconfig
  }
}

resource "cloudflare_dns_record" "secret_c_srv_caldavs" {
  name     = "_caldavs._tcp"
  priority = 0
  proxied  = false
  ttl      = 3600
  type     = "SRV"
  zone_id  = cloudflare_zone.secret_c.id
  data = {
    priority = 0
    weight   = 0
    port     = 443
    target   = var.domeneshop.caldav
  }
}

resource "cloudflare_dns_record" "secret_c_srv_carddavs" {
  name     = "_carddavs._tcp"
  priority = 0
  proxied  = false
  ttl      = 3600
  type     = "SRV"
  zone_id  = cloudflare_zone.secret_c.id
  data = {
    priority = 0
    weight   = 0
    port     = 443
    target   = var.domeneshop.carddav
  }
}

resource "cloudflare_dns_record" "secret_c_txt_caldavs" {
  content = var.domeneshop.dav-path
  name    = "_caldavs._tcp"
  proxied = false
  ttl     = 3600
  type    = "TXT"
  zone_id = cloudflare_zone.secret_c.id
}

resource "cloudflare_dns_record" "secret_c_txt_carddavs" {
  content = var.domeneshop.dav-path
  name    = "_carddavs._tcp"
  proxied = false
  ttl     = 3600
  type    = "TXT"
  zone_id = cloudflare_zone.secret_c.id
}

resource "cloudflare_dns_record" "secret_c_txt_dmarc" {
  content = format(var.domeneshop.dmarc-rua, "mailto:${var.domeneshop.ds-rua},mailto:9d9ec2b190c54675920ea199ad77047e@dmarc-reports.cloudflare.net")
  name    = "_dmarc"
  proxied = false
  ttl     = 3600
  type    = "TXT"
  zone_id = cloudflare_zone.secret_c.id
}

resource "cloudflare_dns_record" "secret_c_txt_spf" {
  content = var.domeneshop.spf-ds
  name    = cloudflare_zone.secret_c.name
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.secret_c.id
}

resource "cloudflare_dns_record" "secret_c_txt_dkim" {
  content = "\"v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAym8sPsYgQGw5X3oZ0/83eUmZchyucsfC+u620Q5TZpoRaxdkuuw3uASq3SUIv1ahzL1Ke8Sv/bnlNl6LEh3ITjwiHy+HXFVlsXqG60DDUeEFyYMWnZ0OfDQGin+Gdwj0yx/WkBQg1oLO6rsqDV9vUDFBPiWfzFN2EfVR8S0/qkyIPnvpbngSsEY+fA+Gpb7\" \"c/fYb0Ink0V2JVtlruaCVRiuB4KmdUlun/rzinlCzQTmSqHac90t3eVpcei4iI0JVwdkDtY2omNGE37oDndo67yJy3AFozPb0EndIWXANvwY/Dmt+5ILE2J8aSg7tSTcR3ElMRkr5fesMuqOKlgBe1wIDAQAB\""
  name    = "ds202503._domainkey"
  proxied = false
  ttl     = 3600
  type    = "TXT"
  zone_id = cloudflare_zone.secret_c.id
}

# The apex record only covers the apex. Without this, a forged envelope sender
# at any subdomain gets an SPF result of "none" rather than "fail", and only
# DMARC stops it. No wildcard CNAME here to conflict with.
resource "cloudflare_dns_record" "secret_c_txt_spf_wc" {
  content = var.domeneshop.spf-ds
  name    = "*"
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.secret_c.id
}
