# OpenTofu — Hetzner

Owns the Hetzner Object Storage buckets (Helsinki, `hel1.your-objectstorage.com`) that hold the
homelab's off-site backups. Both were created in the Cloud Console and imported:

- `sebastka-homelab-databases`: the nightly PGP-encrypted database dumps
  (`k8s/common/dbdump2s3`). Object lock and versioning, with a 30-day COMPLIANCE lock on every new
  version: nothing written can be deleted or overwritten for 30 days, by anyone (see `buckets.tf`
  for why compliance rather than governance). Its lifecycle policy is the dumps' only retention:
  `daily/` 30 days, `monthly/` a year, and each expired version removed a week later.
- `sebastka-homelab`: Velero's backups. Velero manages them itself (30-day TTL), so no lifecycle
  policy, versioning or lock; it is here so the bucket is on record and protected by
  `prevent_destroy`.

The project holds nothing else: no servers, volumes, networks, firewalls, SSH keys, IPs, DNS zones
or Storage Boxes (checked with the hcloud API, 2026-10-18), so there is no hcloud provider here.
Not managed: the S3 key pairs, which only the Cloud Console can create.

A separate root with its own state, like `../tofu-tailscale`: it must be appliable without
Proxmox, the cluster or Cloudflare.

## Layout

| File                | Purpose                                                       |
| ------------------- | ------------------------------------------------------------- |
| `providers.tf`      | Provider constraints, state encryption, the S3 endpoint       |
| `vars.tf`           | The state passphrase                                          |
| `buckets.tf`        | The buckets and their lifecycle policies                      |
| `secrets.sops.yaml` | Committed, PGP-encrypted: the S3 key pair, the passphrase, and an hcloud API token (unused: no hcloud resources) |
| `terraform.tfstate` | Committed, encrypted with the passphrase                      |

## Usage

```sh
direnv allow   # once; decrypts secrets.sops.yaml when the shell enters this directory
./run.sh       # init, fmt, validate, plan, and apply after confirmation
```

## Credentials

Everything is in **`secrets.sops.yaml`**, committed PGP-encrypted; `.envrc` exports it:

| Key                           | Exported as                                                      |
| ----------------------------- | ---------------------------------------------------------------- |
| `state_encryption_passphrase` | `TF_VAR_state_encryption_passphrase` (same value as `../tofu`'s) |
| `s3_access_key`               | `MINIO_USER`                                                     |
| `s3_secret_key`               | `MINIO_PASSWORD`                                                 |

The key pair is created in the Cloud Console (project → Security → S3 credentials). A Hetzner key
reaches every bucket of its project, so a dedicated key buys revocation, not isolation. To replace
it, create a new pair, put it into `secrets.sops.yaml` (`sops secrets.sops.yaml`), then delete the
old one in the Console.

The provider reads both variables itself, so they reach neither state nor the plan file.

## Things worth knowing

- **`s3_compat_mode`** is on: Hetzner implements a subset of S3, and the provider then reports an
  unsupported feature as such rather than failing every read. Creating or changing something
  Hetzner does not support still fails, by design.
- **Both buckets have `prevent_destroy`**: removing one means removing that line first,
  deliberately.
- **Object lock can only be enabled when a bucket is created**, which is why
  `object_locking = true` must stay: false would mean replacing the bucket.
- **Restoring a dump**: see the dbdump2s3 image's README, in the containers repository.
- **A compliance lock cannot be lifted, shortened or bypassed**, not even to delete the bucket: it
  can only be removed once every version in it has outlived its lock. Lowering `validity_period`
  only affects versions written afterwards.
