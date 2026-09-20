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


    # Decrypts secrets.sops.yaml at plan time; see secrets.tf.
    sops = {
      source  = "carlpett/sops"
      version = "~> 1"
    }
  }
}

provider "proxmox" {
  alias     = "hera"
  endpoint  = "https://${var.pve["hera"].domain}:8006"
  api_token = var.pve_api_tokens["hera"]
  insecure  = false

  ssh {
    agent    = true
    username = "ansible"
  }
}

provider "cloudflare" {
  api_token = var.cloudflare.api_token
}

