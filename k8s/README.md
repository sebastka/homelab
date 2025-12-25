# Bootstrap

First, make sure Gateway API CRDs are installed.

## Cilium

https://docs.siderolabs.com/kubernetes-guides/cni/deploying-cilium  
https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/

Cilium provides:
- CNI networking (Replaces Flannel)
- Gateway API implementation (Instead of Ingress)
- LoadBalancer implementation (Replaces MetalLB)

Install:
1. `kubectl kustomize --enable-helm infrastructure/network/cilium | kubectl apply --server-side -f -`

## Sealed Secrets

https://www.arthurkoziel.com/encrypting-k8s-secrets-with-sealed-secrets/

Install Sealed Secrets:
1. `kubectl kustomize --enable-helm ./infrastructure/controllers/sealed-secrets | kubectl apply --server-side -f -`

Usage:
- Seal Cloudflare API Token:
  ```shell
    kubectl create secret generic cloudflare-api-token --from-literal=api-token=$CLOUDFLARE_API_TOKEN --namespace gateway --dry-run=client -o yaml \
        | kubeseal --controller-namespace sealed-secrets --controller-name sealed-secrets-controller --format yaml \
        > ./infrastructure/network/gateway/SealedSecret.yaml
  ```

## Cert-manager

https://cert-manager.io/docs/installation/helm/  
https://artifacthub.io/packages/helm/cert-manager/cert-manager

Install:
1. `kubectl kustomize --enable-helm infrastructure/controllers/cert-manager | kubectl apply --server-side -f -`

## Gateway

Set up Gateway with Cloudflare DNS01 Issuer:
1. `kubectl apply --server-side -k ./infrastructure/network/gateway`

Misc:
- Back up: `kubectl -n gateway get secret wc-karlsen-fr-tls-secret -o yaml > wc-karlsen-fr-tls-secret.yaml`
- Restore: `kubectl apply --server-side -f wc-karlsen-fr-tls-secret.yaml`

## ArgoCD

https://argo-cd.readthedocs.io/en/stable/getting_started/

Install ArgoCD:
1. `kubectl kustomize --enable-helm ./infrastructure/controllers/argocd | kubectl apply --server-side -f -`

Deploy homelab:
1. `kubectl apply -k infrastructure`
2. `kubectl apply -k sets`

## Longhorn

https://longhorn.io/docs/1.9.0/deploy/install/install-with-kubectl/

> [!NOTE]
> Should be deployed automatically by ArgoCD. Investigate the issue.

Install Longhorn:
1. `kubectl kustomize --enable-helm ./infrastructure/storage/longhorn | kubectl apply --server-side -f -`
