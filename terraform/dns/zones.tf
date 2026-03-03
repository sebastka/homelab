# bwdb.info
resource "cloudflare_zone" "bwdbinfo" {
  account = {
    id = var.cloudflare.account_id
  }
  type                = "full"
  vanity_name_servers = []
  name               = "bwdb.info"
}

# karlsen.app
resource "cloudflare_zone" "karlsenapp" {
  account = {
    id = var.cloudflare.account_id
  }
  type                = "full"
  vanity_name_servers = []
  name               = "karlsen.app"
}

# karlsen.fr
resource "cloudflare_zone" "karlsenfr" {
  account = {
    id = var.cloudflare.account_id
  }
  type                = "full"
  vanity_name_servers = []
  name               = "karlsen.fr"
}

# karlsen.org
resource "cloudflare_zone" "karlsenorg" {
  account = {
    id = var.cloudflare.account_id
  }
  type                = "full"
  vanity_name_servers = []
  name               = "karlsen.org"
}

# sebastka.no
resource "cloudflare_zone" "sebastkano" {
  account = {
    id = var.cloudflare.account_id
  }
  type                = "full"
  vanity_name_servers = []
  name               = "sebastka.no"
}

# spkag.com
resource "cloudflare_zone" "spkagcom" {
  account = {
    id = var.cloudflare.account_id
  }
  type                = "full"
  vanity_name_servers = []
  name               = "spkag.com"
}
