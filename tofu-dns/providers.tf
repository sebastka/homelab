terraform {
  encryption {
    key_provider "pbkdf2" "state_key" {
      passphrase = var.state_encryption_passphrase
    }

    method "aes_gcm" "state" {
      keys = key_provider.pbkdf2.state_key
    }

    state {
      method = method.aes_gcm.state
    }

    plan {
      method = method.aes_gcm.state
    }
  }

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 5"
    }
  }
}

# Reads CLOUDFLARE_API_TOKEN from the environment; see .envrc.
provider "cloudflare" {}

