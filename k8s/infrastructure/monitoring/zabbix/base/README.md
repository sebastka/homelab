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
