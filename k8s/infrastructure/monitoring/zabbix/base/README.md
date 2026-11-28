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

Ours, in [assets/templates/](assets/templates), are synced from Git after every Argo CD sync by [Job.template-sync.yaml](Job.template-sync.yaml) ([assets/template-sync.sh](assets/template-sync.sh), Zabbix's API):

- **Import:** each template is created or updated. Within a template, what Git no longer has (items, triggers, graphs, discovery rules…) is deleted.
- **Removal:** a template removed from Git is deleted from Zabbix, but only templates tagged `managed-by: homelab`: every template here carries that tag, and official templates are never touched.
- **Host links:** [assets/template-links.json](assets/template-links.json) (`{"<template>": ["<host>", …]}`, technical names) is the source of truth: missing links are added, links it no longer lists are removed (unlinked and cleared).
- **Adding a template:** export it from Zabbix (or write it), add the `managed-by: homelab` tag, list the file in [kustomization.yaml](kustomization.yaml)'s `zabbix-templates` ConfigMap (kustomize has no globs), and its hosts in `template-links.json`.
- **Authentication:** `TEMPLATE_SYNC_API_TOKEN` in `zabbix-secrets`, the API token of a Zabbix user allowed to write templates and link them to hosts (Users > API tokens). The Job's log shows what it imported, deleted, linked and unlinked; any API error fails it.

Current templates:

- [kopia-backups.yaml](assets/templates/kopia-backups.yaml): the file VM's off-site backups (Kopia's lock renewals and oldest object lock), linked to `file.home.karlsen.fr`.

## TODO: disk health (SMART)

The NixOS servers with SMART disks (helios; not hermes, an SD card) run `smartd` (nixos repo:
`modules/nixos/server/smartd.nix`): nightly short and weekly long self-tests, findings in their journal only
(`journalctl -u smartd`). Zabbix doesn't see them yet. To have per-attribute items and triggers, Zabbix must read
`smartctl` itself:

- **Template**: Zabbix's official *SMART by Zabbix agent 2* uses agent 2's SMART plugin. The servers run the classic
  agent (`zabbix_agentd`, nixos repo: `modules/nixos/server/zabbix-agent.nix`), so either switch them to agent 2, or
  give the classic agent `UserParameter`s that call `smartctl --json` (discovery of the disks, then their attributes)
  with a template matching them.
- **sudo**: `smartctl` needs root. The agent's user then needs a sudo rule for it alone, without password, e.g. in
  `zabbix-agent.nix`: `security.sudo.extraRules` for user `zabbix-agent`, command
  `/run/current-system/sw/bin/smartctl` with `NOPASSWD`. Agent 2's plugin needs the same.
