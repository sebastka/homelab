# Syncthing

The always-on hub between the desktops' Syncthing (nixos repo, `modules/nixos/desktop/syncthing.nix`),
for `~/Documents` and `~/Dev`. The desktops share their folders with it as an **untrusted device**: it
only ever stores them encrypted, and passes them on to the other desktops, which decrypt them.

- Sync: `sync.karlsen.fr:22000` (TCP and QUIC). At home helios resolves it to this LoadBalancer
  (`192.168.2.14`); elsewhere it is the public IP, which helios forwards here (ansible `routers.conf`
  and `unbound`; nixos `hosts/helios`; DNS record in `tofu/dns`). Connections are TLS, mutually
  authenticated by device ID: only devices added here get in.
- Web UI: <https://syncthing.talmox.hera.home.karlsen.fr>, LAN and tailnet only. The `gui` Service is
  ClusterIP, the route is on the internal gateway (not forwarded by helios), and the
  CiliumNetworkPolicy only admits 8384 from that gateway's proxies, never the public one's. Only
  22000 is public. Behind Syncthing's login too (user and password hash in `config.xml`).
- Config and identity in git: `SealedSecret.syncthing-config.yaml` (`config.xml`, with the login and
  API key) and `SealedSecret.syncthing-identity.yaml` (`cert.pem`/`key.pem`: the device ID, kept even
  if the PVC is lost). The plaintext `Secret.*.yaml` next to them are gitignored.
- Data: `syncthing-data-pvc` (index, encrypted folders), with Longhorn recurring snapshots and the
  nightly Velero backup.

## Config changes

The `config` init container copies the Secrets onto the PVC on every start, overwriting the live
`config.xml`: git is the source of truth. Changes made in the web UI (accepting a device or folder)
work, but only until the next restart. Before overwriting, the init container logs the lines the live
config has that git doesn't (`kubectl logs -n syncthing deploy/syncthing -c config`), and the
reverse. To keep a change, add it to `config.xml` in `Secret.syncthing-config.yaml` and reseal it.

After a Syncthing upgrade that changes the config format (the `version` attribute), Syncthing
migrates the copy at every start, and the log lists the differences until git's `config.xml` is
updated too.

## First deployment

1. Create the Longhorn volume `syncthing-data-pv` (20 GiB, `longhorn-encrypted`) and its PV.
2. Sync the kyverno app first (it allows `docker.io/syncthing/syncthing`), then this one.

The config in git already disables global and local discovery, relaying, NAT traversal and usage
reporting (the desktops know the server's address). The device ID is in Actions > Show ID.

## Desktops

1. In the nixos repo: set `serverDeviceId` in `modules/nixos/desktop/syncthing.nix`, and add
   `syncthing-encryption-password` (a long random password, the same on every desktop) to
   `secrets/desktop.sops.yaml`. Rebuild each desktop.
2. Here, accept each desktop's connection request (or add its device ID), then accept the folders it
   offers: they are set up as "Receive Encrypted". Then copy the new `<device>` and `<folder>` entries
   into git's `config.xml` before the next restart, from the live config:
   `kubectl exec -n syncthing deploy/syncthing -- cat /var/syncthing/config/config.xml`.

The encryption password never reaches the server. Keep it safe: without it, the server's copies (and
their backups) cannot be decrypted.
