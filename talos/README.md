# Talos cluster configuration

Machine configuration for the Talos clusters under `clusters/`, managed with
[topf](https://github.com/postfinance/topf). topf renders each node's machine config and applies
it over the Talos API in one step, so nothing is generated into the repo and there is no
rendered output to commit.

Docs: <https://postfinance.github.io/topf/main/>

## Layout

```text
talos/
├── bootstrap.sh                # `full`: apply + etcd bootstrap + kubeconfig; `credentials`: local files only
├── upgrade.sh                  # Longhorn-aware node roller: `topf upgrade`, or plain reboots
└── clusters/talmox/
    ├── topf.yaml               # cluster definition: versions, image factory, nodes, template data
    ├── secrets.sops.yaml       # Talos secrets bundle, sops/PGP encrypted
    ├── sealedsecrets.sops.yaml # sealed-secrets keypair, sops/PGP encrypted
    ├── schematic.yaml          # image factory schematic for t01/t02
    ├── schematic.igpu.yaml     # image factory schematic for t03 (xe/i915)
    ├── all/                    # patches applied to every node
    └── control-plane/          # patches applied to control-plane nodes
```

All three nodes are control planes and run workloads, so there is no `worker/` directory. Nodes
differ only in their zone label and, for t03, the schematic.

## Configuration model

Patches merge in the order `all/` → `control-plane/` → `node/<host>/`, lexicographically inside
each folder, which is why the files are numbered. Later patches win. Everything is a strategic
merge patch (with `$patch: delete` for removals); RFC 6902 JSON patches are not supported.

Files ending in `.tpl` are Go templates rendered with sprig, and get `.ClusterName`,
`.TalosVersion`, `.Data.<key>`, `.Node.Host`, `.Node.Data.<key>` and `.Node.RuntimeData.*`.
Every other file is read through sops and then vals, so any patch may be encrypted in place.

topf reads **every** file in `all/`, `control-plane/` and `node/<host>/` regardless of
extension — renaming a patch to `.disabled` does not switch it off. To park one, move it out
of those directories entirely.

## Usage

Run from this directory. `topf` defaults to `./topf.yaml`, so every command needs the cluster
pointed out, either with `--topfconfig` or via the environment:

```sh
export TOPFCONFIG=./clusters/talmox/topf.yaml
```

| Task | Command |
| ---- | ------- |
| Show what would change, without touching anything | `topf apply --dry-run` (exit code 2 = there are changes) |
| Apply config changes | `topf apply` |
| Render configs to `./output` | `topf render` |
| Bring up a fresh cluster | `./bootstrap.sh talmox full` |
| Rewrite local credentials (expired cert, new workstation) | `./bootstrap.sh talmox credentials` |
| Upgrade Talos | bump `talosVersion`, then `./upgrade.sh talmox` (see below) |
| Roll the nodes without a version change | `./upgrade.sh talmox reboot` (`EVICT=false` to skip the Longhorn evacuation) |
| Upgrade Kubernetes | `talosctl upgrade-k8s --to <version>`, then set `kubernetesVersion` to match |
| Node states | `topf nodes` |
| Check the schematic IDs still resolve | `topf schematic-ids` |
| talosconfig / break-glass kubeconfig | `topf talosconfig`, `topf kubeconfig` (both print to stdout) |
| Add the OIDC user/context | `./bootstrap.sh talmox kubeconfig-oidc` (add `setup` to run `kubectl oidc-login setup` first) |

`--nodes-filter` takes a Go regex over `host` and works on every command, e.g.
`topf upgrade --nodes-filter '^t03\.'`.

## Upgrading Talos

`talosVersion` in `topf.yaml` is the only place the version lives. It produces the installer
image, and `topf upgrade` compares that image against what each node runs, skipping the ones
already there.

```sh
# bump talosVersion in topf.yaml, then
topf apply          # writes the new installer image; no version change yet
./upgrade.sh talmox # one node at a time: evacuate Longhorn, upgrade, reboot, uncordon
```

Kubernetes is upgraded separately, and minor versions go through `talosctl upgrade-k8s`.

## Things worth knowing

- **Both versions are explicit.** `kubernetesVersion` is required, and topf writes the resulting
  image refs (`registry.k8s.io/kube-apiserver:v1.37.0`, `ghcr.io/siderolabs/kubelet:v1.37.0`, …)
  into the machine config. A Kubernetes **minor** upgrade goes through
  `talosctl upgrade-k8s --to <version>`, which validates skew and rolls the components in
  order; `kubernetesVersion` is then set to match so `topf apply` does not revert it. Bumping
  the field and running `topf apply` skips all of those checks and is only safe for patch
  releases.
- **Schematic IDs are computed from the schematic files**, not copied around. `topf schematic-ids`
  must keep printing
  `8dfe2c9a167a9e198aec688d0ed5507a2441b16d65a3fd3f3814b5d684b73b8e` (t01/t02) and
  `a2cece99d5d57ff53fff8237b2673c5aa6ed0072505a2f068f8dd16a0be17181` (t03). A different ID means a
  different installer image, i.e. a reinstall on the next upgrade. New schematics the factory has
  never seen need one run with `--submit-to-factory`.
- **OIDC is structured authentication config, not flags.** kube-apiserver refuses every
  `--oidc-*` flag once `--authentication-config` is set, and Talos always sets it, so
  `all/15-oidc.yaml.tpl` configures `KubeAuthenticationConfig`: issuer URL, `audiences` (the
  client ID) and `claimMappings` for the username/groups claims and their `authelia:` prefixes.
- **Longhorn has no kubelet bind mount.** `machine.kubelet.extraMounts` no longer exists
  ([talos#14365](https://github.com/siderolabs/talos/issues/14365)) and is not needed here:
  Longhorn's `defaultDataPath` is `/var/mnt/longhorn-data`, its replicas live on the user
  volume declared in `all/13-longhorn.yaml`, and `instance-manager` reaches that path through
  its host-root mount. `/var/lib/longhorn` only holds engine binaries and sockets, on EPHEMERAL.
- **Hostnames.** `nodes[].host` is only used by topf for display, logging and node selection. The
  Talos hostnames are left on `auto: stable` (`all/01-hostname.yaml`), which is what keeps the
  Kubernetes node names at `t01`/`t02`/`t03` rather than the FQDNs.
- **The sealed-secrets keypair is kept out of the Talos bundle.** `topf secrets` parses
  `secrets.sops.yaml` into the Talos struct and re-serialises it, which silently drops any key
  Talos does not recognise. Keeping the keypair in `sealedsecrets.sops.yaml` means a stray
  `topf secrets > secrets.sops.yaml` cannot cost you the ability to decrypt the repo's
  SealedSecrets. `bootstrap.sh` writes both halves to `$XDG_CONFIG_HOME/talos/<cluster>/seal.*`.
- **An expired talosctl client certificate is a non-event.** The credential in
  `$XDG_CONFIG_HOME/talos/<cluster>/config.yaml` is minted from the `os` CA in
  `secrets.sops.yaml` and lasts a year; the CA itself runs to 2036. `topf talosconfig` issues a
  fresh one offline, so `./bootstrap.sh talmox credentials` fixes it without touching the
  cluster. Nothing under that directory is a source of truth — it is all derived from this
  repo, and safe to delete and regenerate.
- **Two kinds of cluster access, one kubeconfig.** Everything lands in
  `$XDG_CONFIG_HOME/kube/<cluster>/config.yaml`. `full` and `credentials` write the
  `topf@<cluster>` user — a 12-hour `system:masters` certificate from `topf kubeconfig`,
  break-glass only and with no notion of OIDC. `kubeconfig-oidc` adds an `oidc@<cluster>` user
  and context beside it, wiring the `kubectl oidc-login` exec plugin so normal access goes
  through Authelia and the `authelia:`-prefixed RBAC. Switch between them with
  `kubectl config use-context`. Re-running `credentials` merges rather than overwrites, so it
  refreshes the expired certificate without dropping the OIDC entries or changing the current
  context.
- **Filesystem trim.** Talos ships a `FilesystemTrimConfig` document by default, weekly, at a
  stable per-volume offset, but it cannot reach an encrypted volume unless `allowDiscards` is
  set — and every volume here is LUKS2. It is enabled on EPHEMERAL
  (`all/18-disk-encryption.yaml`) and on `longhorn-data` (`all/13-longhorn.yaml`); STATE is
  left alone, being small and near-static. The flag is read when LUKS opens the volume, so it
  takes effect on each node's next boot. The Proxmox disks are created with `discard = "on"`
  on ZFS, so freed blocks go back to the pool. Check with
  `talosctl -n <ip> read /sys/block/dm-1/queue/discard_max_bytes` — non-zero means it is live.
- **`upgrade.sh` checks for drift, it does not apply.** Before rolling anything it runs
  `topf apply --dry-run` and warns if the nodes do not match the config, since rolling a node
  only activates settings that are already on it. Applying is left to you: it is a change in
  its own right and deserves its own diff review, and `topf upgrade` deliberately does not
  need it — it reads the rendered config for the installer image.
- **`topf upgrade` drains and uncordons by itself**, one control-plane node at a time, and skips
  nodes whose installer image already matches. `upgrade.sh` only adds the Longhorn replica
  evacuation around it.
