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

## Sealed Secrets

https://www.arthurkoziel.com/encrypting-k8s-secrets-with-sealed-secrets/

Install Sealed Secrets:
1. `kubectl kustomize --enable-helm ./infrastructure/controllers/sealed-secrets | kubectl apply --server-side -f -`

Usage:
- Seal Cloudflare API Token: `cat infrastructure/network/gateway/Secret.yaml | kubeseal kubeseal --controller-namespace sealed-secrets --controller-name sealed-secrets-controller --format yaml > infrastructure/network/gateway/SealedSecret.yaml`

## ArgoCD

https://argo-cd.readthedocs.io/en/stable/getting_started/

Install ArgoCD:
1. `kubectl kustomize --enable-helm ./infrastructure/controllers/argocd | kubectl apply --server-side -f -`

ArgoCD CLI login and bootstrap homelab:
1. `argocd login argocd.talmox.hera.home.karlsen.fr --sso` 
2. `argocd proj create homelab --description "Homelab"`
3. `argocd proj add-source homelab https://github.com/sebastka/homelab.git`
4. `argocd repo add https://github.com/sebastka/homelab.git --name homelab --project homelab --type git`

<!--
- `kubectl apply -k infrastructure`
- `kubectl apply -k sets`
-->

## Longhorn

https://longhorn.io/docs/1.9.0/deploy/install/install-with-kubectl/

Install Longhorn:
1. `kubectl kustomize --enable-helm ./infrastructure/storage/longhorn | kubectl apply --server-side -f -`

## Portainer

https://artifacthub.io/packages/helm/portainer/portainer

Install Portainer:
1. `kubectl kustomize --enable-helm ./infrastructure/controllers/portainer | kubectl apply --server-side -f -`

## Whoami

Install Whoami:
1. `kubectl apply --server-side -k ./applications/dev/whoami`

## Paperless

Install Paperless:
1. `kubectl apply --server-side -k ./applications/utils/paperless`
