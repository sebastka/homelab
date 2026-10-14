# OpenTofu — Tailscale

Owns the tailnet's configuration (`hinny-toad.ts.net`):

- the policy file, in [policy/](policy): groups, tag owners, auto-approvers, Tailscale SSH and
  grants, and the tests Tailscale runs against every change. Grants and auto-approvers name
  groups, not people: access changes by editing `policy/groups.hujson`;
- tailnet settings, DNS (MagicDNS and split DNS to helios) and contacts;
- the Kubernetes operator's OAuth client (`talmox-ts-operator`), and the Secret that hands it to
  the operator. The operator's Connector is the tailnet's subnet router for the home LAN
  (`192.168.0.0/16`), its route approved by the policy.

Not managed here: the OAuth client this root authenticates with, personal devices, the
operator's own devices, and global DNS nameservers and search paths (both empty).

A separate root with its own state, because the tailnet is part of the way back in when other
things are down: it must be appliable without Proxmox, the cluster or Cloudflare.

## Layout

| File                | Purpose                                                              |
| ------------------- | -------------------------------------------------------------------- |
| `providers.tf`      | Provider constraints, state encryption                               |
| `vars.tf`           | The state passphrase                                                 |
| `policy.tf`         | The `tailscale_acl` resource, joining `policy/` into one policy file |
| `policy/`           | The policy file, one HuJSON file per top-level key, edited by hand   |
| `tailnet.tf`        | Tailnet settings, DNS, contacts                                      |
| `oauth_clients.tf`  | The operator's OAuth client and its generated Secret                 |
| `templates/`        | The Secret template                                                  |
| `secrets.sops.yaml` | Committed, PGP-encrypted: the OAuth client and the state passphrase  |
| `terraform.tfstate` | Committed, encrypted with the passphrase                             |

## Usage

```sh
direnv allow   # once; decrypts secrets.sops.yaml when the shell enters this directory
./run.sh       # init, fmt, validate, plan, and apply after confirmation
```

## Credentials

Everything is in **`secrets.sops.yaml`**, committed PGP-encrypted; `.envrc` exports it:

| Key                             | Exported as                       |
| ------------------------------- | --------------------------------- |
| `state_encryption_passphrase`   | `TF_VAR_state_encryption_passphrase` (same value as `../tofu`'s) |
| `tailscale_oauth_client_id`     | `TAILSCALE_OAUTH_CLIENT_ID`       |
| `tailscale_oauth_client_secret` | `TAILSCALE_OAUTH_CLIENT_SECRET`   |

The provider authenticates with a Tailscale **OAuth client**, not an API key: its secret does not
expire, and the access tokens the provider exchanges it for last an hour. It is the
`tofu-tailscale` client under **Settings → Trust credentials → OAuth clients**, with every scope.
The provider reads both variables itself, so they reach neither state nor the plan file.

To replace it, create a new client, put its ID and secret into `secrets.sops.yaml`, then revoke
the old one.

## Changing the policy

Each file in `policy/` is a complete HuJSON object holding one top-level key. `policy.tf` joins
them, in a fixed order, into the one document Tailscale stores; a new top-level key needs both a
file and an entry in `policy_parts`. Tailscale stores the policy in its own `hujsonfmt` layout and
the provider compares text, so a file in any other layout shows as a change on every plan. Format
before applying, and keep editors from reformatting these files on save:

```sh
go run github.com/tailscale/hujson/cmd/hujsonfmt@latest -w policy/*.hujson
# without Go installed:
nix shell nixpkgs#go -c go run github.com/tailscale/hujson/cmd/hujsonfmt@latest -w policy/*.hujson
```

The admin console's policy editor is locked (`acls_externally_managed_on`), with a link back to
this directory: `policy/` is the only way to change the policy.

A policy file can lock every device out of the tailnet, including the one running `tofu apply`.
Two guards:

- **`tests` in `policy/tests.hujson`.** Tailscale evaluates them on every update and rejects a
  policy that fails one, before it takes effect. Add a test for any access that must never be
  lost, the admin path above all.
- **Read the plan.** `run.sh` shows the full policy diff and asks before applying.

If it happens anyway, the policy can be reverted from the admin console, or by applying the
previous `policy/` from a device that still has access.

## Things worth knowing

- **Split DNS is one resource per domain** (`tailscale_dns_split_nameservers`), not the
  all-in-one `tailscale_dns_configuration`: in provider 0.29.2 that one reads the domains from an
  unordered map into an ordered list, so plans kept showing them "reordered".
- **The operator's OAuth client secret is shown only once.** `oauth_clients.tf` keeps it in
  state and writes it to `k8s/infrastructure/network/tailscale/overlays/talmox/Secret.operator-oauth.yaml`,
  plaintext and gitignored. Seal it with `seal Secret.operator-oauth.yaml` in that directory,
  commit `SealedSecret.operator-oauth.yaml`, and delete the plaintext file. Rotating it means a
  new client: `tofu state mv` the old one aside, apply, reseal, restart the operator, then drop
  the old client.
