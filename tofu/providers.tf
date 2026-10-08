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
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.107.0"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 5"
    }

    local = {
      source  = "hashicorp/local"
      version = ">= 2.5"
    }
  }
}

# The API token comes from PROXMOX_VE_API_TOKEN, exported by .envrc. Note that
# a provider env var applies to every instance of the provider, so a second
# node with its own token would have to go back to an explicit api_token here.
provider "proxmox" {
  alias    = "hera"
  endpoint = "https://${var.pve["hera"].domain}:8006"
  insecure = false

  ssh {
    agent    = true
    username = "ansible"
  }
}

# Reads CLOUDFLARE_API_TOKEN from the environment; see .envrc.
provider "cloudflare" {}

