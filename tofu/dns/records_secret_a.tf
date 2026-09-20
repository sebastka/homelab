# Secret zone "a" -- name lives in secrets.sops.yaml, records are public.
#
# Mail is deliberately and completely off: the zone neither sends nor receives.
# RFC 7505 null MX refuses delivery at connect time, SPF -all at the apex and
# under the wildcard authorises no sender anywhere in the zone, and DMARC
# p=reject tells receivers what to do when someone forges it anyway. The
# Domeneshop autoconfig, autodiscover and DAV records were removed with the
# mailboxes.
#
# Apex A record is rewritten hourly by cf-record-update on Helios; unmanaged.

resource "cloudflare_dns_record" "secret_a_caa" {
  name    = cloudflare_zone.secret_a.name
  proxied = false
  ttl     = 1
  type    = "CAA"
  zone_id = cloudflare_zone.secret_a.id
  data = {
    flags = 128
    tag   = "issue"
    value = "letsencrypt.org"
  }
}

resource "cloudflare_dns_record" "secret_a_cname_www" {
  content = cloudflare_zone.secret_a.name
  name    = "www"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  zone_id = cloudflare_zone.secret_a.id
}

# Null MX (RFC 7505): this domain accepts no mail. A sender fails immediately
# instead of timing out against a host that was never going to answer.
resource "cloudflare_dns_record" "secret_a_mx_null" {
  content  = "."
  name     = cloudflare_zone.secret_a.name
  priority = 0
  proxied  = false
  ttl      = 1
  type     = "MX"
  zone_id  = cloudflare_zone.secret_a.id
}

resource "cloudflare_dns_record" "secret_a_txt_spf" {
  content = var.domeneshop.spf-empty
  name    = cloudflare_zone.secret_a.name
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.secret_a.id
}

# The apex record only covers the apex. Without this, a forged envelope sender
# at any subdomain gets an SPF result of "none" rather than "fail", and only
# DMARC stops it -- so receivers that check SPF but not DMARC would let it by.
resource "cloudflare_dns_record" "secret_a_txt_spf_wc" {
  content = var.domeneshop.spf-empty
  name    = "*"
  proxied = false
  ttl     = 1
  type    = "TXT"
  zone_id = cloudflare_zone.secret_a.id
}

# rua goes to Cloudflare only; the Domeneshop address went with the mailboxes.
resource "cloudflare_dns_record" "secret_a_txt_dmarc" {
  content = format(var.domeneshop.dmarc-rua, "mailto:fe220f49f8c040a1a1c01a44b17a2d54@dmarc-reports.cloudflare.net")
  name    = "_dmarc"
  proxied = false
  ttl     = 3600
  type    = "TXT"
  zone_id = cloudflare_zone.secret_a.id
}
