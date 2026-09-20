output "zones" {
  description = "Cloudflare zone ids, keyed by zone name"
  sensitive   = true
  value = {
    (cloudflare_zone.karlsenapp.name) = cloudflare_zone.karlsenapp.id
    (cloudflare_zone.karlsenfr.name)  = cloudflare_zone.karlsenfr.id
    (cloudflare_zone.karlsenorg.name) = cloudflare_zone.karlsenorg.id
    (cloudflare_zone.secret_a.name)   = cloudflare_zone.secret_a.id
    (cloudflare_zone.secret_c.name)   = cloudflare_zone.secret_c.id
    (cloudflare_zone.secret_e.name)   = cloudflare_zone.secret_e.id
  }
}

output "aliases" {
  description = "Which secret alias is which domain -- the mapping, for humans"
  sensitive   = true
  value = {
    a = cloudflare_zone.secret_a.name
    c = cloudflare_zone.secret_c.name
    e = cloudflare_zone.secret_e.name
  }
}

output "nameservers" {
  description = "Delegation to check at the registrar, keyed by alias or name"
  sensitive   = true
  value = {
    "karlsen.app" = cloudflare_zone.karlsenapp.name_servers
    "karlsen.fr"  = cloudflare_zone.karlsenfr.name_servers
    "karlsen.org" = cloudflare_zone.karlsenorg.name_servers
    a             = cloudflare_zone.secret_a.name_servers
    c             = cloudflare_zone.secret_c.name_servers
    e             = cloudflare_zone.secret_e.name_servers
  }
}
