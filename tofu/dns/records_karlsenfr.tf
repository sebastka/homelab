# karlsen.fr -- the primary zone: homelab ingress, mail, Matrix, PGP.

# The apex A record is rewritten hourly by cf-record-update on Helios, so it is
# deliberately left unmanaged. Adding it here would fight the DDNS script.
#   A  karlsen.fr  ->  <Helios / enp1s0>

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

# Service names, all CNAMEd onto the apex A record.

# Authelia / OIDC
resource "cloudflare_dns_record" "karlsenfr_cname_auth" {
  content = cloudflare_zone.karlsenfr.name
  name    = "auth"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.karlsenfr.id
}

# Thunderbird autoconfig, served by us -- not by Domeneshop
resource "cloudflare_dns_record" "karlsenfr_cname_autoconfig" {
  content = cloudflare_zone.karlsenfr.name
  name    = "autoconfig"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.karlsenfr.id
}

resource "cloudflare_dns_record" "karlsenfr_cname_captcha" {
  content = cloudflare_zone.karlsenfr.name
  name    = "captcha"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.karlsenfr.id
}

# Forgejo
resource "cloudflare_dns_record" "karlsenfr_cname_git" {
  content = cloudflare_zone.karlsenfr.name
  name    = "git"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.karlsenfr.id
}

# LLDAP
resource "cloudflare_dns_record" "karlsenfr_cname_ldap" {
  content = cloudflare_zone.karlsenfr.name
  name    = "ldap"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.karlsenfr.id
}

# Matrix Authentication Service
resource "cloudflare_dns_record" "karlsenfr_cname_mas" {
  content = cloudflare_zone.karlsenfr.name
  name    = "mas"
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

# policy host for the _mta-sts TXT below
resource "cloudflare_dns_record" "karlsenfr_cname_mta-sts" {
  content = cloudflare_zone.karlsenfr.name
  name    = "mta-sts"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.karlsenfr.id
}

# WKD
resource "cloudflare_dns_record" "karlsenfr_cname_openpgpkey" {
  content = cloudflare_zone.karlsenfr.name
  name    = "openpgpkey"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.karlsenfr.id
}

resource "cloudflare_dns_record" "karlsenfr_cname_www" {
  content = cloudflare_zone.karlsenfr.name
  name    = "www"
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

# Null MX (RFC 7505) for subdomains: only the apex receives mail.
resource "cloudflare_dns_record" "karlsenfr_mx_wc" {
  content  = "."
  name     = "*"
  priority = 0
  proxied  = false
  ttl      = 1
  type     = "MX"
  zone_id  = cloudflare_zone.karlsenfr.id
}

# Mail client autodiscovery, served by Domeneshop.
resource "cloudflare_dns_record" "karlsenfr_srv_autodiscover" {
  name     = "_autodiscover._tcp"
  priority = 0
  proxied  = false
  ttl      = 1
  type     = "SRV"
  zone_id  = cloudflare_zone.karlsenfr.id
  data = {
    priority = 0
    weight   = 0
    port     = 443
    target   = var.domeneshop.autoconfig
  }
}

# Libravatar federation for @karlsen.fr addresses. Clients resolve this, then
# fetch https://<target>/avatar/<md5-or-sha256 of the lowercased address>.
resource "cloudflare_dns_record" "karlsenfr_srv_avatars_sec" {
  name     = "_avatars-sec._tcp"
  priority = 0
  proxied  = false
  ttl      = 1
  type     = "SRV"
  zone_id  = cloudflare_zone.karlsenfr.id
  data = {
    priority = 0
    weight   = 0
    port     = 443
    target   = "www.karlsen.fr"
  }
}

resource "cloudflare_dns_record" "karlsenfr_srv_caldavs" {
  name     = "_caldavs._tcp"
  priority = 0
  proxied  = false
  ttl      = 3600
  type     = "SRV"
  zone_id  = cloudflare_zone.karlsenfr.id
  data = {
    priority = 0
    weight   = 0
    port     = 443
    target   = var.domeneshop.caldav
  }
}

resource "cloudflare_dns_record" "karlsenfr_srv_carddavs" {
  name     = "_carddavs._tcp"
  priority = 0
  proxied  = false
  ttl      = 1
  type     = "SRV"
  zone_id  = cloudflare_zone.karlsenfr.id
  data = {
    priority = 0
    weight   = 0
    port     = 443
    target   = var.domeneshop.carddav
  }
}

resource "cloudflare_dns_record" "karlsenfr_srv_imaps" {
  name     = "_imaps._tcp"
  priority = 0
  proxied  = false
  ttl      = 1
  type     = "SRV"
  zone_id  = cloudflare_zone.karlsenfr.id
  data = {
    priority = 0
    weight   = 1
    port     = 993
    target   = var.domeneshop.imap
  }
}

resource "cloudflare_dns_record" "karlsenfr_srv_submissions" {
  name     = "_submissions._tcp"
  priority = 0
  proxied  = false
  ttl      = 1
  type     = "SRV"
  zone_id  = cloudflare_zone.karlsenfr.id
  data = {
    priority = 0
    weight   = 1
    port     = 465
    target   = var.domeneshop.smtp
  }
}

resource "cloudflare_dns_record" "karlsenfr_txt_caldavs" {
  content = var.domeneshop.dav-path
  name    = "_caldavs._tcp"
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.karlsenfr.id
}

resource "cloudflare_dns_record" "karlsenfr_txt_carddavs" {
  content = var.domeneshop.dav-path
  name    = "_carddavs._tcp"
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.karlsenfr.id
}

resource "cloudflare_dns_record" "karlsenfr_txt_dmarc" {
  content = format(var.domeneshop.dmarc-ruf-rua, "mailto:ruf@karlsen.fr", "mailto:${var.domeneshop.ds-rua},mailto:rua@karlsen.fr")
  name    = "_dmarc"
  proxied = false
  ttl     = 1
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

# Bump the id whenever the policy document changes, or senders keep the cached
# copy until max_age expires. Last change: max_age 86400 -> 1209600.
resource "cloudflare_dns_record" "karlsenfr_txt_mta-sts" {
  content = "v=STSv1; id=1789935207;"
  name    = "_mta-sts"
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.karlsenfr.id
}

resource "cloudflare_dns_record" "karlsenfr_txt_tls_smtp" {
  content = "v=TLSRPTv1; rua=mailto:tlsrpt@karlsen.fr"
  name    = "_smtp._tls"
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.karlsenfr.id
}

resource "cloudflare_dns_record" "karlsenfr_cname_dkim_ds" {
  content = "ds202503.karlsen.fr.dkim.domeneshop.no"
  name    = "ds202503._domainkey"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.karlsenfr.id
}

# BIMI. Empty "a=" declares no VMC, so this is self-asserted: mailbox providers
# that require a mark certificate (Gmail) will not render the logo.
resource "cloudflare_dns_record" "karlsenfr_txt_bimi" {
  content = "v=BIMI1; l=https://www.karlsen.fr/icons/K.svg; a=; avp=personal;" # lvs= (local part selector, if I want a logo for sebastian@karlsen.fr only)
  name    = "default._bimi"
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.karlsenfr.id
}

# Domain-ownership proofs.
resource "cloudflare_dns_record" "karlsenfr_txt_verify_anthropic" {
  content = "\"anthropic-domain-verification-r394h4=dz4Gr4mXPVml4Q3hPbFmcZQas\""
  name    = cloudflare_zone.karlsenfr.name
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.karlsenfr.id
}

resource "cloudflare_dns_record" "karlsenfr_txt_verify_openai" {
  content = "\"openai-domain-verification=dv-QQTAFEuzuzXY5gybDjnktrA4\""
  name    = cloudflare_zone.karlsenfr.name
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.karlsenfr.id
}

resource "cloudflare_dns_record" "karlsenfr_txt_verify_tailscale" {
  content = "\"TAILSCALE-g6rDWqQAfTJPKHMoTTym\""
  name    = cloudflare_zone.karlsenfr.name
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.karlsenfr.id
}

# WKD-over-DNS for sebastian@karlsen.fr. See the README for how to rebuild the
# owner name and content after a key change.
resource "cloudflare_dns_record" "karlsenfr_openpgpkey_sebastian" {
  content = "mDMEaq1dgBYJKwYBBAHaRw8BAQdASA7cwfTLDThvAkjBQERRwz1NGPkvEzwHG1C6shzA19+0KFNlYmFzdGlhbiBLYXJsc2VuIDxzZWJhc3RpYW5Aa2FybHNlbi5mcj6ImQQTFgoAQRYhBAslsmxTe0C1sgjzpsdMAuZtDL7PBQJqrV2AAhsBBQkDwmcABQsJCAcCAiICBhUKCQgLAgQWAgMBAh4HAheAAAoJEMdMAuZtDL7P5wwA/1vvlS1tXFI72VSr6pAR2vKeenk4vbN1JMyS71I1YvXYAQC5KOeO4hRcqAdDAhfeiUtlz79VLuE8b3FavzloLXIxA7gzBGqtXfAWCSsGAQQB2kcPAQEHQPpwCIVNuhWrYkgMhh+H1LEOvSbVOBtJuDWbjpWC5XKoiPQEGBYKACYWIQQLJbJsU3tAtbII86bHTALmbQy+zwUCaq1d8AIbAgUJAeEzgACBCRDHTALmbQy+z3YgBBkWCgAdFiEE70Q1MpVF2DHW6W+9NUlTFL5XHaMFAmqtXfAACgkQNUlTFL5XHaPeZAEAvWU5NUUjVLuUN0nAKDnmuWcJ3+UWUraq4aR9w3mM0gIA/RWGCWQjBTB1fockyEMh2WjOuadOeEwBGXQn2xkAoIwHRmYA/RzT5m0SdUWWCwHTHzaejJ69DTgJb5Uys9SNGS9fn4LZAPii4gmp7XWWGuJOt2XJkIqoL7GYEBHGO1A1lLk1d1kEuDgEaq1eABIKKwYBBAGXVQEFAQEHQNvEJiRsh8XAO68CAG/fY60fGCCVyr0wGOPr0nvedi4fAwEIB4h+BBgWCgAmFiEECyWybFN7QLWyCPOmx0wC5m0Mvs8FAmqtXgACGwwFCQHhM4AACgkQx0wC5m0Mvs+gwQEAoiRDov+MWhoeO+hW2tyGzJY+Xp1FvDMFW6mcPr/w6x8BANonTMayccloxq5nqfKVB3nReNVdVPwhknddolHSft8FuDMEaq1eChYJKwYBBAHaRw8BAQdACjE+rhyVKBbZKZim92VHsZYY4cX4Sjxk2SZ2/NrS2Z2IfgQYFgoAJhYhBAslsmxTe0C1sgjzpsdMAuZtDL7PBQJqrV4KAhsgBQkB4TOAAAoJEMdMAuZtDL7Pr94BAJT+GvkGUXN4RJoPdVfyUvpYRPnugzEfrxY35QXbZdtNAP94DLcIW8a15d0NFBRB+nSRhA3+krZXR5TEMFkclLszCA=="
  name    = "4dd68e2ab3a30973318ea903e088b3d3480655ef4236109fe47272c1._openpgpkey"
  proxied = false
  ttl     = 1
  type    = "OPENPGPKEY"
  zone_id = cloudflare_zone.karlsenfr.id
}

# The apex record only covers the apex. Without this, a forged envelope sender
# at any subdomain gets an SPF result of "none" rather than "fail", and only
# DMARC stops it. No wildcard CNAME here to conflict with.
resource "cloudflare_dns_record" "karlsenfr_txt_spf_wc" {
  content = "\"v=spf1 -all\""
  name    = "*"
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.karlsenfr.id
}
