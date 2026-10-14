terraform {
  required_version = ">= 1.11"

  # Local state, committed and encrypted like ../tofu's, with its own passphrase. A separate root
  # because the tailnet is part of the way back in when other things are down: it must be
  # appliable without Proxmox, the cluster or Cloudflare.
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
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.29"
    }

    # Writes the operator's OAuth client into a Secret under ../k8s; see oauth_clients.tf.
    local = {
      source  = "hashicorp/local"
      version = ">= 2.5"
    }
  }
}

# TAILSCALE_OAUTH_CLIENT_ID and TAILSCALE_OAUTH_CLIENT_SECRET, exported by .envrc from
# secrets.sops.yaml. The provider reads them itself, so they reach neither state nor the plan
# file. The tailnet is the one that owns the OAuth client.
provider "tailscale" {}
