output "zones" {
  description = "Cloudflare zone ids, keyed by zone name"
  value = {
    (cloudflare_zone.karlsenapp.name) = cloudflare_zone.karlsenapp.id
    (cloudflare_zone.karlsenfr.name)  = cloudflare_zone.karlsenfr.id
    (cloudflare_zone.karlsenorg.name) = cloudflare_zone.karlsenorg.id
    (cloudflare_zone.bwdbinfo.name)   = cloudflare_zone.bwdbinfo.id
    (cloudflare_zone.spkagcom.name)   = cloudflare_zone.spkagcom.id
    (cloudflare_zone.megkano.name)    = cloudflare_zone.megkano.id
  }
}

output "nameservers" {
  description = "Delegation to check at the registrar, keyed by zone name"
  value = {
    (cloudflare_zone.karlsenapp.name) = cloudflare_zone.karlsenapp.name_servers
    (cloudflare_zone.karlsenfr.name)  = cloudflare_zone.karlsenfr.name_servers
    (cloudflare_zone.karlsenorg.name) = cloudflare_zone.karlsenorg.name_servers
    (cloudflare_zone.bwdbinfo.name)   = cloudflare_zone.bwdbinfo.name_servers
    (cloudflare_zone.spkagcom.name)   = cloudflare_zone.spkagcom.name_servers
    (cloudflare_zone.megkano.name)    = cloudflare_zone.megkano.name_servers
  }
}
