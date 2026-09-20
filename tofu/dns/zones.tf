# Public zones.

resource "cloudflare_zone" "karlsenapp" {
  account             = { id = var.cloudflare.account_id }
  name                = "karlsen.app"
  type                = "full"
  vanity_name_servers = []
}

resource "cloudflare_zone" "karlsenfr" {
  account             = { id = var.cloudflare.account_id }
  name                = "karlsen.fr"
  type                = "full"
  vanity_name_servers = []
}

resource "cloudflare_zone" "karlsenorg" {
  account             = { id = var.cloudflare.account_id }
  name                = "karlsen.org"
  type                = "full"
  vanity_name_servers = []
}

# Zones whose names we do not publish. The name is the only secret; every
# record below it is declared in the open, in records_secret_<alias>.tf.

resource "cloudflare_zone" "secret_a" {
  account             = { id = var.cloudflare.account_id }
  name                = var.secret_zones.a
  type                = "full"
  vanity_name_servers = []
}

resource "cloudflare_zone" "secret_c" {
  account             = { id = var.cloudflare.account_id }
  name                = var.secret_zones.c
  type                = "full"
  vanity_name_servers = []
}

# Moved off Domeneshop's nameservers onto Cloudflare on 2026-09-20. Mail and
# the parking host stay with Domeneshop; only DNS hosting changed.

resource "cloudflare_zone" "secret_e" {
  account             = { id = var.cloudflare.account_id }
  name                = var.secret_zones.e
  type                = "full"
  vanity_name_servers = []
}
