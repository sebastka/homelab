# Bootstrap

1. First, make sure Gateway API CRDs are installed.
2. Install Cilium and Envoy:  `kubectl kustomize --enable-helm infrastructure/network/cilium | kubectl apply --server-side -f -`
3. Install Sealed Secrets: `kubectl kustomize --enable-helm ./infrastructure/controllers/sealed-secrets | kubectl apply --server-side -f -`
4. Seal Cloudflare API token and update the sealed secret: 
  ```bash
    kubectl create secret generic cloudflare-api-token --from-literal=api-token=$CLOUDFLARE_API_TOKEN --namespace gateway --dry-run=client -o yaml \
        | kubeseal --controller-namespace sealed-secrets --controller-name sealed-secrets-controller --format yaml \
        > ./infrastructure/network/gateway/SealedSecret.yaml
  ```
5. Install cert-manager: `kubectl kustomize --enable-helm infrastructure/controllers/cert-manager | kubectl apply --server-side -f -`
6.  Set up Gateway with Cloudflare DNS01 Issuer: `kubectl apply --server-side -k ./infrastructure/network/gateway`
7. Install ArgoCD:  `kubectl kustomize --enable-helm ./infrastructure/controllers/argocd | kubectl apply --server-side -f -`
8.  Deploy homelab:
  - `kubectl apply -k infrastructure`
  - `kubectl apply -k sets`
9. (To be removed) Install Longhorn: `kubectl kustomize --enable-helm ./infrastructure/storage/longhorn | kubectl apply --server-side -f -`
