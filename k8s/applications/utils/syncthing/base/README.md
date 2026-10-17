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
  22000 is public. Behind Syncthing's login too: the init container sets its credentials from
  `SealedSecret.syncthing-gui.yaml` on every start.
- Data: `syncthing-data-pvc` (config, keys, index, encrypted folders), with Longhorn recurring
  snapshots and the nightly Velero backup.

## First deployment

1. Create the Longhorn volume `syncthing-data-pv` (20 GiB, `longhorn-encrypted`) and its PV.
2. Sync the kyverno app first (it allows `docker.io/syncthing/syncthing`), then this one.
3. In the web UI:
   - Settings > Connections: untick global discovery, local discovery, relaying and NAT traversal
     (the desktops know its address). Keep the listen address `default`.
   - Settings > General: usage reporting off.
   - Remove the "Default Folder" that `syncthing generate` creates (it is shared with no one).
   - Actions > Show ID: the server's device ID.

## Desktops

1. In the nixos repo: set `serverDeviceId` in `modules/nixos/desktop/syncthing.nix`, and add
   `syncthing-encryption-password` (a long random password, the same on every desktop) to
   `secrets/desktop.sops.yaml`. Rebuild each desktop.
2. Here, accept each desktop's connection request (or add its device ID), then accept the folders it
   offers: they are set up as "Receive Encrypted".

The encryption password never reaches the server. Keep it safe: without it, the server's copies (and
their backups) cannot be decrypted.
