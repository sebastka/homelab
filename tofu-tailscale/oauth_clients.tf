# The Tailscale Kubernetes operator's OAuth client on talmox. It may only tag devices with
# tag:k8s-operator's tags (policy/tagOwners.hujson), and its Connector is the tailnet's subnet
# router for the home LAN (192.168.0.0/16, auto-approved in policy/autoApprovers.hujson).
#
# Tailscale shows a client's secret only on creation, so it is in state, and from there written to
# a plaintext Secret in the operator's talmox overlay. That file is gitignored (Secret.*.yaml): seal
# it with `seal`, which writes SealedSecret.operator-oauth.yaml beside it, and commit that. A change
# to scopes, tags or the description replaces the client, and with it the secret, hence
# prevent_destroy. The client this root itself uses is deliberately not managed here.
resource "tailscale_oauth_client" "operator" {
  description = "talmox-ts-operator"
  scopes      = ["auth_keys", "devices:core", "services"]
  tags        = ["tag:k8s-operator"]

  # The tag has to exist in the policy first.
  depends_on = [tailscale_acl.policy]

  lifecycle {
    prevent_destroy = true
  }
}

# The Secret the tailscale-operator chart reads its credentials from, by this exact name.
resource "local_sensitive_file" "operator_oauth" {
  filename        = "${path.module}/../k8s/infrastructure/network/tailscale/overlays/talmox/Secret.operator-oauth.yaml"
  file_permission = "0600"

  content = templatefile("${path.module}/templates/Secret.operator-oauth.yaml.tftpl", {
    client_id     = tailscale_oauth_client.operator.id
    client_secret = tailscale_oauth_client.operator.key
  })
}
