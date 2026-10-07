locals {
  cloudflare_account_id = "e39cff0632bc814188cfcf1d3a22f2a9"
}

# Public zones.

resource "cloudflare_zone" "karlsenapp" {
  account             = { id = local.cloudflare_account_id }
  name                = "karlsen.app"
  type                = "full"
  vanity_name_servers = []
}

resource "cloudflare_zone" "karlsenfr" {
  account             = { id = local.cloudflare_account_id }
  name                = "karlsen.fr"
  type                = "full"
  vanity_name_servers = []
}

resource "cloudflare_zone" "karlsenorg" {
  account             = { id = local.cloudflare_account_id }
  name                = "karlsen.org"
  type                = "full"
  vanity_name_servers = []
}

resource "cloudflare_zone" "bwdbinfo" {
  account             = { id = local.cloudflare_account_id }
  name                = "bwdb.info"
  type                = "full"
  vanity_name_servers = []
}

resource "cloudflare_zone" "spkagcom" {
  account             = { id = local.cloudflare_account_id }
  name                = "spkag.com"
  type                = "full"
  vanity_name_servers = []
}

resource "cloudflare_zone" "megkano" {
  account             = { id = local.cloudflare_account_id }
  name                = "megka.no"
  type                = "full"
  vanity_name_servers = []
}
