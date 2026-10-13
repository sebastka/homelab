# shellcheck shell=sh
# Sourced by bin/seal and bin/unseal.
#
# The sealed-secrets keypair lives in talos/clusters/<cluster>/sealedsecrets.sops.yaml, as
# base64 under `crt` and `key`. It is decrypted into memory and handed to kubeseal on stdin, so
# neither half is ever written to disk. CLUSTER selects the cluster (default: talmox).
CLUSTER="${CLUSTER:-talmox}"
SOPS_FILE="${ROOT}/talos/clusters/${CLUSTER}/sealedsecrets.sops.yaml"

# keypair_value <crt|key>
#
# Decrypted in its own step rather than in a pipeline: inside a pipeline a sops failure (no PGP
# key, wrong file) would go unnoticed and hand kubeseal an empty certificate or key.
keypair_value()
{
    encoded="$(sops -d --extract "[\"$1\"]" "$SOPS_FILE")"
    printf -- '%s' "$encoded" | base64 -d
}

# usage <pattern>
usage()
{
    printf -- 'usage: %s %s...\n' "${0##*/}" "$1" >&2
    exit 1
}
