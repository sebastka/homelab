# Tailnet-wide settings, DNS and contacts.

resource "tailscale_tailnet_settings" "this" {
  # Locks the admin console's policy editor: policy/ is the only way to change the policy.
  acls_externally_managed_on = true
  acls_external_link         = "https://github.com/sebastka/homelab/tree/master/tofu-tailscale/policy"

  devices_approval_on                         = false
  devices_auto_updates_on                     = true
  devices_key_duration_days                   = 180
  users_approval_on                           = true
  users_role_allowed_to_join_external_tailnet = "admin"
  https_enabled                               = true
  network_flow_logging_on                     = false
  posture_identity_collection_on              = false
  regional_routing_on                         = false
}

# MagicDNS, with the home zones answered by helios's resolver (unbound) through hermes's route.
#
# One resource per split-DNS domain rather than the all-in-one tailscale_dns_configuration: that
# one reads the domains from an unordered map into an ordered list (provider 0.29.2), so every
# plan showed them "reordered". Global nameservers and search paths are empty and not managed.
resource "tailscale_dns_preferences" "this" {
  magic_dns = true
}

resource "tailscale_dns_split_nameservers" "home" {
  for_each = toset(["home.karlsen.fr", "karlsen.app", "karlsen.org"])

  domain      = each.key
  nameservers = ["192.168.0.1"]
}

resource "tailscale_contacts" "this" {
  account {
    email = "sebastian@karlsen.fr"
  }
  support {
    email = "sebastian@karlsen.fr"
  }
  security {
    email = "sebastian@karlsen.fr"
  }
}
