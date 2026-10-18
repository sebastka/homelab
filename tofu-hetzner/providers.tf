terraform {
  required_version = ">= 1.11"

  # Local state, committed and encrypted like ../tofu's, with the same passphrase. A separate root,
  # like ../tofu-tailscale: Hetzner holds the off-site backups, so it must be appliable without
  # Proxmox, the cluster or Cloudflare.
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
    # Hetzner Object Storage speaks S3, not the hcloud API, which has no object storage resources:
    # Hetzner documents this provider for it. https://docs.hetzner.com/storage/object-storage/getting-started/creating-a-bucket-minio-terraform/
    minio = {
      source  = "aminueza/minio"
      version = "~> 3.45"
    }
  }
}

# Object storage in Helsinki, where the buckets are. MINIO_USER and MINIO_PASSWORD, exported by
# .envrc from secrets.sops.yaml, are an S3 key pair from the Cloud Console (they cannot be created
# through any API). The provider reads them itself, so they reach neither state nor the plan file.
provider "minio" {
  minio_server = "hel1.your-objectstorage.com"
  minio_region = "hel1"
  minio_ssl    = true

  # Hetzner implements a subset of S3: unsupported features are reported as such instead of
  # failing every read.
  s3_compat_mode = true
}
