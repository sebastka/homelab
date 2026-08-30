#!/bin/bash
set -euo pipefail

TALMOX_IP=192.168.2.100  # talmox clustermesh-apiserver LB IP
HYADES_IP=192.168.3.100  # hyades clustermesh-apiserver LB IP
PORT=2379

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# ── Extract CAs from both clusters ───────────────────────────────────────────

kubectl --context admin@talmox get secret cilium-ca -n kube-system \
  -o jsonpath='{.data.ca\.crt}' | base64 -d > "$TMPDIR/talmox-ca.crt"
kubectl --context admin@talmox get secret cilium-ca -n kube-system \
  -o jsonpath='{.data.ca\.key}' | base64 -d > "$TMPDIR/talmox-ca.key"

kubectl --context admin@hyades get secret cilium-ca -n kube-system \
  -o jsonpath='{.data.ca\.crt}' | base64 -d > "$TMPDIR/hyades-ca.crt"
kubectl --context admin@hyades get secret cilium-ca -n kube-system \
  -o jsonpath='{.data.ca\.key}' | base64 -d > "$TMPDIR/hyades-ca.key"

# ── Generate client certs (each signed by the REMOTE cluster's CA) ───────────

# talmox client cert — signed by hyades CA, used by talmox to connect to hyades
# CN=remote: required by authMode=migration (legacy/migration both use the common "remote" CN)
openssl genrsa -out "$TMPDIR/talmox-client.key" 4096
openssl req -new -key "$TMPDIR/talmox-client.key" -subj "/CN=remote" \
  -out "$TMPDIR/talmox-client.csr"
openssl x509 -req -in "$TMPDIR/talmox-client.csr" \
  -CA "$TMPDIR/hyades-ca.crt" -CAkey "$TMPDIR/hyades-ca.key" -CAcreateserial \
  -days 1825 -out "$TMPDIR/talmox-client.crt"

# hyades client cert — signed by talmox CA, used by hyades to connect to talmox
openssl genrsa -out "$TMPDIR/hyades-client.key" 4096
openssl req -new -key "$TMPDIR/hyades-client.key" -subj "/CN=remote" \
  -out "$TMPDIR/hyades-client.csr"
openssl x509 -req -in "$TMPDIR/hyades-client.csr" \
  -CA "$TMPDIR/talmox-ca.crt" -CAkey "$TMPDIR/talmox-ca.key" -CAcreateserial \
  -days 1825 -out "$TMPDIR/hyades-client.crt"

# ── Create clustermesh secrets on each cluster ───────────────────────────────
# cilium-clustermesh : read by cilium-agents to discover remote clusters
# cilium-kvstoremesh : read by kvstoremesh to connect to remote apiservers

printf 'endpoints:\n- "https://%s:%s"\ntrusted-ca-file: /var/lib/cilium/clustermesh/hyades-cacert\ncert-file: /var/lib/cilium/clustermesh/hyades.crt\nkey-file: /var/lib/cilium/clustermesh/hyades.key\n' \
  "$HYADES_IP" "$PORT" > "$TMPDIR/hyades-config"

printf 'endpoints:\n- "https://%s:%s"\ntrusted-ca-file: /var/lib/cilium/clustermesh/talmox-cacert\ncert-file: /var/lib/cilium/clustermesh/talmox.crt\nkey-file: /var/lib/cilium/clustermesh/talmox.key\n' \
  "$TALMOX_IP" "$PORT" > "$TMPDIR/talmox-config"

for SECRET in cilium-clustermesh cilium-kvstoremesh; do
  kubectl --context admin@talmox create secret generic "$SECRET" \
    -n kube-system \
    --from-file=hyades="$TMPDIR/hyades-config" \
    --from-file=hyades-cacert="$TMPDIR/hyades-ca.crt" \
    --from-file=hyades.crt="$TMPDIR/talmox-client.crt" \
    --from-file=hyades.key="$TMPDIR/talmox-client.key" \
    --dry-run=client -o yaml | kubectl --context admin@talmox apply -f -

  kubectl --context admin@hyades create secret generic "$SECRET" \
    -n kube-system \
    --from-file=talmox="$TMPDIR/talmox-config" \
    --from-file=talmox-cacert="$TMPDIR/talmox-ca.crt" \
    --from-file=talmox.crt="$TMPDIR/hyades-client.crt" \
    --from-file=talmox.key="$TMPDIR/hyades-client.key" \
    --dry-run=client -o yaml | kubectl --context admin@hyades apply -f -
done

echo "Done. Verify with: cilium clustermesh status --context admin@talmox"
