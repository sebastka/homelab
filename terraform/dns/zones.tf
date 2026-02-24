# bwdb.info
resource "cloudflare_zone" "bwdbinfo" {
  account_id          = var.cloudflare.account_id
  paused              = false
  plan                = "free"
  type                = "full"
  vanity_name_servers = []
  zone                = "bwdb.info"
}

# karlsen.app
resource "cloudflare_zone" "karlsenapp" {
  account_id          = var.cloudflare.account_id
  paused              = false
  plan                = "free"
  type                = "full"
  vanity_name_servers = []
  zone                = "karlsen.app"
}

# karlsen.fr
resource "cloudflare_zone" "karlsenfr" {
  account_id          = var.cloudflare.account_id
  paused              = false
  plan                = "free"
  type                = "full"
  vanity_name_servers = []
  zone                = "karlsen.fr"
}

# karlsen.org
resource "cloudflare_zone" "karlsenorg" {
  account_id          = var.cloudflare.account_id
  paused              = false
  plan                = "free"
  type                = "full"
  vanity_name_servers = []
  zone                = "karlsen.org"
}

# sebastka.no
resource "cloudflare_zone" "sebastkano" {
  account_id          = var.cloudflare.account_id
  paused              = false
  plan                = "free"
  type                = "full"
  vanity_name_servers = []
  zone                = "sebastka.no"
}

# spkag.com
resource "cloudflare_zone" "spkagcom" {
  account_id          = var.cloudflare.account_id
  paused              = false
  plan                = "free"
  type                = "full"
  vanity_name_servers = []
  zone                = "spkag.com"
}
