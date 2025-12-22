# Bootstrap

## Gateway API:

https://gateway-api.sigs.k8s.io/guides/

Gateway API requires custom resource definitions (CRDs) to be installed in the cluster:
1. `kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml`
2. `kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.4.0/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml`

<!-- https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/experimental-install.yaml -->

## Cilium

https://docs.siderolabs.com/kubernetes-guides/cni/deploying-cilium  
https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/

Cilium provides:
- CNI networking (Replaces Flannel)
- Gateway API implementation (Instead of Ingress)
- LoadBalancer implementation (Replaces MetalLB)

Install:
1. `helm repo add cilium https://helm.cilium.io/`
2. `helm repo update`
3. `helm install cilium cilium/cilium --namespace kube-system --values=./infrastructure/network/cilium/values.yaml`
4. `kubectl apply -f ./infrastructure/network/cilium/CiliumLoadBalancerIPPool.yaml`
5. `kubectl apply -f ./infrastructure/network/cilium/CiliumL2AnnouncementPolicy.yaml`

<!-- - `kubectl kustomize --enable-helm infrastructure/network/cilium | kubectl apply -f -` -->

## Cert-manager

https://cert-manager.io/docs/installation/helm/  
https://artifacthub.io/packages/helm/cert-manager/cert-manager

Install:
1. `helm install cert-manager oci://quay.io/jetstack/charts/cert-manager --namespace cert-manager --create-namespace --values=./infrastructure/controllers/cert-manager/values.yaml`

## Gateway

Set up Gateway with Cloudflare DNS01 Issuer:
1. `kubectl apply -f ./infrastructure/network/gateway/Namespace.yaml`
2. `kubectl apply -f ./infrastructure/network/gateway/Secret.yaml`
3. `kubectl apply -f ./infrastructure/network/gateway/Issuer.yaml`
4. `kubectl apply -f ./infrastructure/network/gateway/Gateway.yaml`
5. `kubectl apply -f ./infrastructure/network/gateway/HTTPRoute.yaml`

Back up:
- `kubectl -n gateway get secret wc-karlsen-fr-tls-secret -o yaml > wc-karlsen-fr-tls-secret.yaml`

Restore:
- `kubectl apply -f wc-karlsen-fr-tls-secret.yaml`

## Whoami

Install Whoami:
1. `kubectl apply -f ./applications/dev/whoami/Namespace.yaml`
2. `kubectl apply -f ./applications/dev/whoami/Deployment.yaml`
3. `kubectl apply -f ./applications/dev/whoami/Service.yaml`
4. `kubectl apply -f ./applications/dev/whoami/HTTPRoute.yaml`

## Longhorn

https://longhorn.io/docs/1.9.0/deploy/install/install-with-kubectl/

Install Longhorn:
1. `kubectl apply -f ./infrastructure/storage/longhorn/Namespace.yaml`
2. `helm repo add longhorn https://charts.longhorn.io`
3. `helm repo update`
4. `helm install longhorn longhorn/longhorn --namespace longhorn-system --values=./infrastructure/storage/longhorn/values.yaml`
5. `kubectl apply -f ./infrastructure/storage/longhorn/HTTPRoute.yaml`

## Portainer

https://artifacthub.io/packages/helm/portainer/portainer

Install Portainer:
1. `kubectl apply -f ./infrastructure/controllers/portainer/Namespace.yaml`
2. `helm repo add portainer https://portainer.github.io/k8s/`
3. `helm repo update`
4. `helm install portainer portainer/portainer --namespace portainer --values=./infrastructure/controllers/portainer/values.yaml`
5. `kubectl apply -f ./infrastructure/controllers/portainer/HTTPRoute.yaml`

## ArgoCD

https://argo-cd.readthedocs.io/en/stable/getting_started/

Install ArgoCD:
1. `kubectl apply -f ./infrastructure/controllers/argocd/Namespace.yaml`
2. `helm repo add argo https://argoproj.github.io/argo-helm`
3. `helm repo update`
4. `helm install argocd argo/argo-cd --namespace argocd --values=./infrastructure/controllers/argocd/values.yaml`

First log in:
- User: `admin`
- Password: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`

<!--
## To be reviewd

- Sealed secrets: `kubectl kustomize --enable-helm infrastructure/controllers/sealed-secrets | kubectl apply -f -`

- ArgoCD:
  - `kustomize build --enable-helm infrastructure/controllers/argocd | kubectl apply -f -`
  - `kubectl apply -k infrastructure`
  - `kubectl apply -k sets`

- Storage:
  - `kubectl kustomize --enable-helm infrastructure/storage/rook | kubectl apply --server-side -f -`
-->
