# Bootstrap

1. First, make sure Gateway API CRDs are installed.
2. Install Cilium and Envoy:  `kubectl kustomize --enable-helm infrastructure/network/cilium | kubectl apply --server-side -f -`
3. Install cert-manager: `kubectl kustomize --enable-helm infrastructure/controllers/cert-manager | kubectl apply --server-side -f -`
4. Set up Gateway with Cloudflare DNS01 Issuer: `kubectl kustomize --enable-helm --enable-alpha-plugins ./infrastructure/network/gateway | kubectl apply --server-side -f -`
5. Install ArgoCD:  `kubectl kustomize --enable-helm ./infrastructure/controllers/argocd | kubectl apply --server-side -f -`
6. Provide the cluster with the Age private key: `cat "$XDG_CONFIG_HOME/sops/age/keys.txt" | kubectl create secret generic sops-age -n argocd --from-file=keys.txt=/dev/stdin`
7.  Deploy homelab:
  - `kubectl apply -k infrastructure`
  - `kubectl apply -k sets`
