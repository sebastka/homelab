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
