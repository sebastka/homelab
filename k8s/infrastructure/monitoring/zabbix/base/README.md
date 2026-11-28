# Zabbix

## LDAP

- **Name**: `LLDAP`
- **Host**: `ldaps://light-ldap.light-ldap.svc.cluster.local`
- **Port**: `636`
- **Base DN**: `ou=people,dc=karlsen,dc=fr`
- **Search attribute**: `uid`
- **Bind DN**: `uid=zabbix,ou=people,dc=karlsen,dc=fr`
- **Bind password**: `*****`
- **Description**:
- **Configure JIT provisioning**: `true`
- **Groupe configuration**: `memberOf`
- **Group name attribute**: `cn`
- **User group membership attribute**: `memberOf`
- **User name attribute**: `givenName`
- **User last name attribute**: `sn`
- **User group mapping**:
  - `{"LDAP group pattern": "k8s_admins", "User groups": ["Zabbix administrators"], "User role": ["Super admin role"]}`
  - `{"LDAP group pattern": "k8s_users", "User groups": ["Guests"], "User role": ["Guest role"]}`
- **Media type mapping**:
  - `{"Name": "E-mail", "Media type": ["Email"], "Attribute": "email"}`
- **StartTLS**: `false`
- **Search filter**: `NULL`

**NB**: Remember to add a group to "Deprovisioned users group" under the "Authentication" tab.

## Templates

Ours, in [assets/templates/](assets/templates), and the official ones we use, are synced from Git after every Argo CD sync by [Job.template-sync.yaml](Job.template-sync.yaml) ([assets/template-sync.sh](assets/template-sync.sh), Zabbix's API):

- **Import:** each template is created or updated. Within a template, what Git no longer has (items, triggers, graphs, discovery rules…) is deleted.
- **Official templates:** the ones [assets/official-templates.txt](assets/official-templates.txt) lists (paths under `templates/` in [Zabbix's repository](https://github.com/zabbix/zabbix)) are imported from the tag of the running server's version (`apiinfo.version`, e.g. `8.0.0`), so upgrading Zabbix upgrades them at the next sync. What the new version no longer has is deleted, history included, as are changes made to them in the UI: customize through host macros, or a template of ours. List there each official template linked in `template-links.json`. Needs egress to `raw.githubusercontent.com` (CiliumNetworkPolicy.yaml).
- **Removal:** a template removed from Git is deleted from Zabbix, but only templates tagged `managed-by: homelab`: every template here carries that tag, and official templates are never touched.
- **Host links:** [assets/template-links.json](assets/template-links.json) (`{"<template>": ["<host>", …]}`, technical names) is the source of truth for every template-host link, ours and official templates alike: missing links are added, links it doesn't list are removed (unlinked and cleared, history included). Only discovered hosts are left alone (their templates come from their host prototype). Link and unlink templates there, not in the UI: the next sync reverts UI changes.
- **file's interface:** passive checks (e.g. *Systemd by Zabbix agent 2*) reach the file VM through the `zabbix-agent` Service (storage/file/base/Service.yaml): its interface in Zabbix connects by DNS to `zabbix-agent.file.svc.cluster.local`, not by IP (the VM's pod address changes with each restart; autoregistration records the address of the time). Set it again by hand if the host is ever re-created.
- **New hosts:** the autoregistration action *NixOS* links *Linux by Zabbix agent active* to each new NixOS server. Add the host to `template-links.json` (under that template, and any other) before the next sync, or that sync unlinks it.
- **Adding a template:** export it from Zabbix (or write it), add the `managed-by: homelab` tag, list the file in [kustomization.yaml](kustomization.yaml)'s `zabbix-templates` ConfigMap (kustomize has no globs), and its hosts in `template-links.json`.
- **Authentication:** `TEMPLATE_SYNC_API_TOKEN` in `zabbix-secrets`, the API token of a Zabbix user allowed to write templates and link them to hosts (Users > API tokens). The Job's log shows what it imported, deleted, linked and unlinked; any API error fails it.

Current templates:

- [kopia-backups.yaml](assets/templates/kopia-backups.yaml): the file VM's off-site backups (Kopia's lock renewals and oldest object lock), linked to `file.home.karlsen.fr`.

## Disk health (SMART)

The NixOS servers with SMART disks (helios, file; not hermes, an SD card) run `smartd` (nixos repo: `modules/nixos/server/smartd.nix`): nightly short and weekly long self-tests, findings in their journal (`journalctl -u smartd`). In Zabbix, per-disk items and triggers come from the official *SMART by Zabbix agent 2 active* template (active: the agents only run active checks), linked to both in `template-links.json`. It needs agent 2's SMART plugin (nixos repo: `modules/nixos/server/zabbix-agent.nix`): `Plugins.Smart.Path` points to `smartctl`, which the plugin always runs as `sudo -n smartctl ...`, allowed to the agent's user (that command only, without password).
