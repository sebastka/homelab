# Bootstrap

1. Install Cilium:
  - `kustomize build --enable-helm infrastructure/network/cilium | kubectl apply --server-side -f -`
  - `kubectl apply --server-side -f infrastructure/network/cilium/CiliumL2AnnouncementPolicy.yaml -f infrastructure/network/cilium/CiliumLoadBalancerIPPool.yaml`
2. Install Sealed Secrets:
  - `kustomize build --enable-helm infrastructure/controllers/sealed-secrets | kubectl apply --server-side -f -`
3. Install cert-manager:
  - `kustomize build --enable-helm infrastructure/controllers/cert-manager | kubectl apply --server-side -f -`
  - `kubectl apply --server-side -f infrastructure/controllers/cert-manager/ClusterIssuer.yaml`
4. Set up Gateway:
  - `kubectl apply --server-side -k infrastructure/network/gateway`
  - (Optional: restore saved certificates) `for f in infrastructure/network/gateway/Secret.*-certificate.yaml; do kubectl apply --server-side -f "$f"; done`
5. Install ArgoCD:
  - `kustomize build --enable-helm infrastructure/controllers/argocd | kubectl apply --server-side -f -`
6.  Deploy infrastructure and applications:
  - `kubectl apply --server-side -k infrastructure`
  - `kubectl apply --server-side -k sets`

# Cheat sheet

Kube overview:
- `watch -n 5 kubectl get nodes -o wide`
- `watch -n 5 kubectl get deployments -o wide -A`
- `watch -n 5 kubectl get pods -o wide -A`
- `watch -n 5 kubectl get svc -o wide -A`

View resource pod usage:
- `watch -n 5 kubectl top pods --sort-by=memory -A`
- `watch -n 5 kubectl top pods --sort-by=cpu -A`

Force delete namespace:
- `kubectl delete all --all -n {namespace}`
- `kubectl delete namespace {namespace}`

Clean up failede and completed pods:
- `kubectl delete -A pods --field-selector status.phase=Failed`
- `kubectl delete -A pods --field-selector=status.phase=Succeeded`

Run debug container on node ([siderolabs.com](https://www.siderolabs.com/blog/how-to-ssh-into-talos-linux/)):
- `kubectl debug -n kube-system -it --image alpine:edge node/w01`
- `apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing igt-gpu-tools pciutils`

Open container shell:
- `kubectl -n MY_NAMESPACE exec -it pods/MY_POO_ID -c MY_CONTAINER -- /bin/bash`

Copy files to a container:
- `kubectl -n MY_NAMESPACE cp ./ MY_DEPLOYMENT:MY_PATH -c MY_CONTAINER`
