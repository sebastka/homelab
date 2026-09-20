# The one secret that is committed rather than kept only on this machine: the
# alias-to-domain mapping for the zones we do not publish. Credentials all live
# in secrets.auto.tfvars, which is gitignored -- losing those costs a few
# minutes of re-issuing tokens, whereas losing this mapping would make dns/
# unreadable.
#
# secrets.sops.yaml is PGP-encrypted with the key in ../.sops.yaml. Decryption
# happens in-process at plan time and needs the private key in gpg-agent.
#
#   Edit:    sops secrets.sops.yaml
#   Decrypt: sops -d secrets.sops.yaml >.secrets.sops.yaml   (gitignored)
#   Encrypt: sops -e .secrets.sops.yaml >secrets.sops.yaml
data "sops_file" "secrets" {
  source_file = "${path.module}/secrets.sops.yaml"
}

locals {
  secrets = yamldecode(data.sops_file.secrets.raw)
}
