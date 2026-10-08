# OpenTofu

Proxmox guests and DNS, in one root module with one encrypted state file.

```sh
./run.sh   # init, fmt, validate, plan -- then apply on confirmation
```

`run.sh` stops and shows the plan before touching anything; press enter to
apply, Ctrl-C or Ctrl-D to walk away. It exits without prompting when the plan
is empty or errored.

`run.sh` unlocks `secrets.sops.yaml` up front, before the plan starts writing.
That is deliberate: the sops provider would otherwise decrypt partway through
the plan, and `pinentry-curses` draws on the same terminal, so the plan's own
output scrolls the prompt away. Running `tofu plan` by hand hits exactly that,
so warm the agent first:

```sh
sops -d secrets.sops.yaml >/dev/null && tofu plan -out=tfplan
```

A graphical pinentry avoids the clash altogether — drop `pinentry-program` from
`~/.gnupg/gpg-agent.conf` and Fedora's wrapper picks `pinentry-qt`. Either way,
`default-cache-ttl` is 36000s, so it is one prompt per day.

## Layout

| Path | What |
| --- | --- |
| `providers.tf` | Provider versions, state encryption, Proxmox and Cloudflare endpoints |
| `secrets.tf` | Reads `secrets.sops.yaml` into `local.secrets` |
| `secrets.sops.yaml` | Committed, PGP-encrypted: every credential |
| `.envrc` | direnv: exports the state passphrase and both provider tokens from sops |
| `locals.tf` | The guest inventory, per Proxmox node |
| `modules.tf` | Wires `dns/` and `virtual_machines/` |
| `ansible.tf` | Writes `../ansible/inventories/tofu.yaml` on apply; commit it with the state |
| `dns/` | Cloudflare zones and records, and the `bin/` tooling around them |
| `vars.domeneshop.tf` | Domeneshop's mail hosts and the SPF/DMARC strings built from them |
| `virtual_machines/` | VM and LXC resources for one Proxmox node |

## Secrets

Everything is in **`secrets.sops.yaml`**, committed PGP-encrypted. Nothing
sensitive is on disk in the clear.

How each value reaches OpenTofu depends on when it is needed:

- **State passphrase** — `TF_VAR_state_encryption_passphrase`. The encryption
  block is evaluated before variables are, so it cannot come from the data
  source.
- **Provider tokens** — `CLOUDFLARE_API_TOKEN` and `PROXMOX_VE_API_TOKEN`, read
  natively by the providers. Provider configuration is resolved before data
  sources too.
- **Everything else** — `local.secrets`, via the `sops_file` data source in
  `secrets.tf`.

`.envrc` exports the first two; `run.sh` refuses to run if they are missing.

Keeping credentials out of the sops file also keeps `provider "domeneshop"`
free of a dependency on `data.sops_file`: a provider whose configuration comes
from a data source is unusable if that read ever fails.

```sh
sops secrets.sops.yaml                          # edit in place
sops -d secrets.sops.yaml >.secrets.sops.yaml   # decrypt to the gitignored copy
sops -e .secrets.sops.yaml >secrets.sops.yaml   # re-encrypt it
```

Both the state and the plan file are encrypted with the `pbkdf2` key provider
(`var.state_encryption_passphrase`). Plan encryption matters as much as state:
without it `tfplan` is a zip of plaintext JSON carrying the whole state and
every input variable, the passphrase included. Both are still gitignored.

## DNS

Six domains, registered at Domeneshop and delegated to Cloudflare's
nameservers.

Each zone has its own file, named after the domain with the dots removed:

| Zone | File |
| --- | --- |
| `karlsen.app` | `dns/records_karlsenapp.tf` |
| `karlsen.fr` | `dns/records_karlsenfr.tf` |
| `karlsen.org` | `dns/records_karlsenorg.tf` |
| `bwdb.info` | `dns/records_bwdbinfo.tf` |
| `spkag.com` | `dns/records_spkagcom.tf` |
| `megka.no` | `dns/records_megkano.tf` |

Three of these were previously held behind aliases `a`–`e` in
`secrets.sops.yaml`. That was dropped on 2026-10-07: the names were the only
secret, they leak from DNS and WHOIS anyway, and the indirection cost more in
readability than it bought.

The apex `A` record of every Cloudflare zone is rewritten hourly by
`cf-record-update` on Helios, so it is deliberately left unmanaged. Each
records file says so where the record would otherwise go.

### Adopting records created elsewhere

Everything is in state already. To adopt a record added outside OpenTofu --
in the Cloudflare dashboard, say -- declare it in the right `records_*.tf`,
then write an `import` block for it in the root module and apply:

```hcl
import {
  to = module.dns.cloudflare_dns_record.<name>
  id = "<zone_id>/<record_id>"
}
```

Delete the block once the apply is through. It is inert while the resource is
in state, but the id goes stale: if the record is later replaced or removed
from state, the block fails the plan with "cannot import non-existent remote
object".

### Zonefile dumps

```sh
dns/bin/export_zonefiles.sh            # -> dns/zonefiles/
dns/bin/export_zonefiles.sh /tmp/dns   # or somewhere else
```

The domain list comes from the registrar rather than from this repo, so a
domain bought and then forgotten still turns up. Cloudflare zones use the
API's own BIND export; Domeneshop has no export endpoint, so those are rebuilt
record by record from `dns:list` and carry no SOA.

Two fixes are applied on the way out. Cloudflare writes the SOA owner without
a trailing dot, which BIND reads as `<zone>.<zone>` and rejects, so the script
re-qualifies it. The Domeneshop dumps get their NS set from `domains:get`,
since the records API does not return it. All eight then pass
`named-checkzone` (the Domeneshop ones once you prepend an SOA).

The dumps are reference copies and never an input to OpenTofu.
`dns/zonefiles/` is gitignored as a directory, not file by file -- a zonefile
is its domain name written out over and over, filename included, and naming
them individually in `.gitignore` would leak exactly what we are hiding.

### Checking

```sh
dns/bin/check_zones.sh           # NS, MX, SPF, DMARC, DKIM, CAA, MTA-STS, DNSSEC
dns/bin/check_zones.sh dmarc     # one section
```

It reads the secret zone names through sops, so nothing is hardcoded, and
resolves against 1.1.1.1 rather than the system resolver -- see the note on
`zone_hosts` in `dns/bin/lib/common`.

```sh
dns/bin/universal_ssl.sh             # report Universal SSL per zone
dns/bin/universal_ssl.sh --disable   # turn it off, so our CAA is served
```

Needs a token with **Zone > SSL and Certificates > Edit**; the DNS token in
`secrets.sops.yaml` cannot reach that endpoint. Pass it as
`CLOUDFLARE_SSL_TOKEN`.

The OPENPGPKEY record in `dns/records_karlsenfr.tf` is WKD-over-DNS for
`sebastian@karlsen.fr`. To rebuild it after a key change, the owner name is the
SHA-1 z-base-32 of the local part and the content is the minimal exported key:

```sh
gpg --export --export-options export-minimal,no-export-attributes <key-id> | base64 -w0
```

## Providers

- **[bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)** — VMs and LXC.
- **[cloudflare/cloudflare](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs)** v5.
- **[carlpett/sops](https://registry.terraform.io/providers/carlpett/sops/latest/docs)** — decrypts
  `secrets.sops.yaml`.

## Known gaps

True of the live zones as of 2026-09-20. Neither is a mistake in this
configuration; both are waiting on something outside it.

- **`karlsen.org` publishes `p=reject` with no DKIM.** It accepts mail and
  tells receivers to reject anything unaligned, but has no `_domainkey`
  record, so DMARC can only ever pass on SPF. Any path that rewrites the
  envelope sender -- mailing lists, `.forward`, most forwarding -- breaks SPF
  with no signature to fall back on, and the mail is rejected rather than
  filtered. The key does not exist at any selector; Domeneshop has to issue
  one. Raised with their support. Once it arrives it is one resource here,
  matching the `ds*` selectors `karlsen.fr`, `c` and `e` already carry.
- **No MTA-STS or TLS-RPT on `c` or `e`.** Both accept mail, so a downgrade
  attack on inbound SMTP is neither blocked nor reported. The serving side is
  ready: `dns/bin/`'s policy document is shared by every zone, since they all
  deliver to the same MX and the policy names no domain. Each still needs a
  Gateway listener and certificate, its hostname on the homepage `discovery`
  HTTPRoute and on the `mta-sts` `server_name`, then an `mta-sts` CNAME,
  `_mta-sts` TXT and `_smtp._tls` TXT here.

`dns/bin/check_zones.sh` reports the current posture of every zone across NS,
MX, SPF, DMARC, DKIM, CAA, MTA-STS and DNSSEC, reading the secret names
through sops.
