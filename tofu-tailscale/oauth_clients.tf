# helios's OAuth client: it joins the tailnet as tag:router and advertises the home LAN (sebastka/nixos:
# hosts/helios/tailscale.nix). Its secret goes to tailscale-oauth-client-secret in sebastka/nixos's
# secrets/helios.sops.yaml, by hand (sops edit there): tofu output -raw helios_oauth_client_secret
resource "tailscale_oauth_client" "helios" {
  description = "helios-subnet-router"
  scopes      = ["auth_keys"]
  tags        = ["tag:router"]
  # The tag has to exist in the policy first.
  depends_on = [tailscale_acl.policy]
  lifecycle {
    prevent_destroy = true
  }
}

output "helios_oauth_client_secret" {
  value     = tailscale_oauth_client.helios.key
  sensitive = true
}
