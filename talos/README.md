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
├── kubeconfig.sh               # (re)writes the kubeconfig (break-glass admin + OIDC) and sealed-secrets keypair
├── upgrade.sh                  # Longhorn-aware node roller: `topf upgrade`, or plain reboots
└── clusters/talmox/
    ├── topf.yaml               # cluster definition: versions, image factory, nodes, template data
    ├── secrets.sops.yaml       # Talos secrets bundle, sops/PGP encrypted
    ├── sealedsecrets.sops.yaml # sealed-secrets keypair, sops/PGP encrypted
    ├── schematic.yaml          # image factory schematic, for every node
    ├── all/                    # patches applied to every node
    ├── control-plane/          # patches applied to control-plane nodes
    └── node/<host>/            # per-node patches: links, EPHEMERAL cap, hardware specifics
```

Three control planes, all running workloads, so there is no `worker/` directory:

| Node | Hardware | Address | Network |
| ---- | -------- | ------- | ------- |
| hera | ASUS NUC 15 Pro+, bare metal, two NVMe (the 9100 PRO is the file VM's, on `vfio-pci`) | 192.168.0.40 | `lan0` (one port) |
| hestia | ASUS NUC 16 Pro, bare metal, one NVMe | 192.168.0.50 | `bond0` over harmonia ports 3+4 |
| dike | ASUS NUC 16 Pro, bare metal, one NVMe | 192.168.0.60 | `bond0` over harmonia ports 5+6 |

What differs per node lives in `nodes[].data` (zone label, main link, install disk serial, MACs)
and in `node/<host>/`. Every node is bare metal, so `platform: metal` and the schematic are set
once, at the top of `topf.yaml`.

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
| Roll out a schematic change (extension, kernel argument) | `topf apply`, then `./upgrade.sh talmox`: it compares the installer image, so only the affected nodes roll |
| Roll the nodes without a version change | `./upgrade.sh talmox reboot` (`EVICT=false` to skip the Longhorn evacuation) |
| Upgrade Kubernetes | `talosctl upgrade-k8s --to <version>`, then set `kubernetesVersion` to match |
| Node states | `topf nodes` |
| Check the schematic IDs still resolve | `topf schematic-ids` |
| talosconfig / break-glass kubeconfig | `topf talosconfig`, `topf kubeconfig` (both print to stdout) |
| Rewrite the kubeconfig only | `./kubeconfig.sh talmox` (add `setup` to run `kubectl oidc-login setup` first) |

`--nodes-filter` takes a Go regex over `host` and works on every command, e.g.
`topf upgrade --nodes-filter '^dike\.'`.

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

## Adding a bare-metal NUC

One node at a time; each one joins etcd as it is applied. hestia is used as the example.

1. **Image.** Submit the schematic once with `topf schematic-ids --submit-to-factory`, then
   write
   `https://factory.talos.dev/image/<schematic.yaml ID>/v<talosVersion>/metal-amd64-secureboot.iso`
   to a USB stick.
2. **Firmware.** Make sure the TPM (Intel PTT) is on: the NUCs' disks are sealed against it.
   Enable Secure Boot and put it in *Setup Mode* by clearing the keys.
   Enrollment is not automatic on bare metal (only in VMs): on the first boot from USB, press
   Esc in the boot menu and pick **Enroll Secure Boot keys: auto**. The node then reboots with
   Secure Boot enforcing.
3. **One cable only.** harmonia's LAG is static, so a node that is not bonded yet must only be
   on one of its two ports. Boot from USB into maintenance mode, and check that
   `talosctl get securitystate --insecure -n <address>` shows `SECUREBOOT true`.
4. **MACs and disk.** `talosctl get links --insecure -n <address from the DHCP pool>`. Fill `mac0`
   (the port that is plugged in) and `mac1` in `topf.yaml`, and `installDisk` with the install
   disk's serial from `talosctl get disks --insecure -n <address>`. Until the new node is
   applied, limit topf runs to the others with `--nodes-filter` (or `TOPF_NODES_FILTER`). Do not
   run `upgrade.sh` meanwhile: it reads every node from `topf.yaml` itself and would try to roll
   the new one too.
5. **Address.** Add a Kea reservation for `mac0` (hostname `hestia`, 192.168.0.50) and the
   DNS records on helios, deploy them, then reboot the node so it comes back on its address.
6. **Apply.** `topf apply --nodes-filter '^hestia\.'`. Talos installs to the NVMe drive and
   reboots into the cluster. Check with `talosctl -n 192.168.0.50 etcd members` and
   `kubectl get nodes`.
7. **Second cable.** Plug it in, then check that both members are up:
   `talosctl -n 192.168.0.50 read /proc/net/bonding/bond0`.

## Things worth knowing

- **Both versions are explicit.** `kubernetesVersion` is required, and topf writes the resulting
  image refs (`registry.k8s.io/kube-apiserver:v1.37.0`, `ghcr.io/siderolabs/kubelet:v1.37.0`, …)
  into the machine config. A Kubernetes **minor** upgrade goes through
  `talosctl upgrade-k8s --to <version>`, which validates skew and rolls the components in
  order; `kubernetesVersion` is then set to match so `topf apply` does not revert it. Bumping
  the field and running `topf apply` skips all of those checks and is only safe for patch
  releases.
- **Schematic IDs are computed from the schematic file**, not copied around. `topf schematic-ids`
  must keep printing
  `a0e669220b6b31597a405507ddd55d5c9aa532811f70815113caea19e2e5a249`. A different ID means a
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
  Talos hostnames are left on `auto: stable` (`all/01-hostname.yaml`), so the name handed out
  by the Kea reservation wins, which is what keeps the Kubernetes node names at `hera`…`dike`
  rather than the FQDNs. `upgrade.sh` relies on `data.zone` being that same name.
- **etcd has three members, one per machine** (hera, hestia, dike; t01, the Proxmox VM hera ran
  before it ran Talos itself, and t02 and t03 were retired). Any one machine can go down, and the
  remaining two keep quorum.
- **Talos and Longhorn share the system disk.** `node/<host>/02-volumes.yaml` caps EPHEMERAL,
  since it would otherwise take the whole drive, and `longhorn-data` (`all/13-longhorn.yaml`,
  `system_disk`) grows into the rest: hera (1 TB MP600 Micro) and hestia (1 TB 990 PRO) have
  128 GiB + ~800 GiB, dike (250 GB 980) 64 GiB + ~166 GiB. The cap is set at install time. dike's 980 is DRAM-less and rated for ~150 TBW,
  so it is the first drive to replace.
- **Disks are sealed against the TPM** (`all/18-disk-encryption.yaml` and
  `all/13-longhorn.yaml`): STATE, EPHEMERAL and `longhorn-data` only open on that NUC, booted with Secure Boot on and the enrolled keys in place. Anything that
  changes the Secure Boot state, such as clearing or re-enrolling the keys or a BIOS update that
  resets them, leaves the volumes locked. The way back is wiping the node and applying it again,
  which costs its etcd membership and Longhorn replicas until they rebuild from the other nodes.
- **The sealed-secrets keypair is kept out of the Talos bundle.** `topf secrets` parses
  `secrets.sops.yaml` into the Talos struct and re-serialises it, which silently drops any key
  Talos does not recognise. Keeping the keypair in `sealedsecrets.sops.yaml` means a stray
  `topf secrets > secrets.sops.yaml` cannot cost you the ability to decrypt the repo's
  SealedSecrets. `kubeconfig.sh` writes both halves to `$XDG_CONFIG_HOME/kube/<cluster>/seal.*`.
- **An expired talosctl client certificate is a non-event.** The credential in
  `$XDG_CONFIG_HOME/talos/<cluster>/config.yaml` is minted from the `os` CA in
  `secrets.sops.yaml` and lasts a year; the CA itself runs to 2036. `topf talosconfig` issues a
  fresh one offline, so `./bootstrap.sh talmox credentials` fixes it without touching the
  cluster. Nothing under that directory is a source of truth — it is all derived from this
  repo, and safe to delete and regenerate.
- **Two kinds of cluster access, one kubeconfig.** Everything lands in
  `$XDG_CONFIG_HOME/kube/<cluster>/config.yaml`, written by `kubeconfig.sh` (which `full` and
  `credentials` call). The `topf@<cluster>` user is break-glass only, with no notion of OIDC: an
  exec plugin, `topf-kube-credential`, mints a fresh 12-hour `system:masters` certificate with
  `topf kubeconfig` on each use, so no admin key is stored and it never goes stale (each call
  decrypts `secrets.sops.yaml`, so expect gpg). The plugin is generic, taking only the cluster's
  `topf.yaml` (by absolute path, as its argument), and must be on `PATH` under that bare name:
  it comes from the NixOS configuration, `users/sebastian/scripts/topf-kube-credential.sh`. The
  `oidc@<cluster>` user beside it wires the `kubectl oidc-login` exec plugin so normal access
  goes through Authelia and the `authelia:`-prefixed RBAC. Switch between them with
  `kubectl config use-context`. With a kuberc in `Allowlist` mode, allow both by name:
  `kubectl-oidc_login` and `topf-kube-credential`. The file is regenerated from scratch on each
  run; only the current context is carried over, and a first run leaves `topf@<cluster>` current.
- **Filesystem trim.** Talos ships a `FilesystemTrimConfig` document by default, weekly, at a
  stable per-volume offset, but it cannot reach an encrypted volume unless `allowDiscards` is
  set — and every volume here is LUKS2. It is enabled on EPHEMERAL
  (`all/18-disk-encryption.yaml`) and on `longhorn-data` (`all/13-longhorn.yaml`); STATE is
  left alone, being small and near-static. The flag is read when LUKS opens the volume, so it
  takes effect on each node's next boot. Check with
  `talosctl -n <ip> read /sys/block/dm-1/queue/discard_max_bytes` — non-zero means it is live.
- **`upgrade.sh` checks for drift, it does not apply.** Before rolling anything it runs
  `topf apply --dry-run` and warns if the nodes do not match the config, since rolling a node
  only activates settings that are already on it. Applying is left to you: it is a change in
  its own right and deserves its own diff review, and `topf upgrade` deliberately does not
  need it — it reads the rendered config for the installer image.
- **`topf upgrade` drains and uncordons by itself**, one control-plane node at a time, and skips
  nodes whose installer image already matches. `upgrade.sh` only adds the Longhorn replica
  evacuation around it.
