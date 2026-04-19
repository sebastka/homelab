# Bootstrap

1. Install CRDs:
  - `kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-community/helm-charts/refs/heads/main/charts/kube-prometheus-stack/charts/crds/crds/crd-servicemonitors.yaml`
  - `kubectl apply --server-side -f https://github.com/grafana/grafana-operator/releases/download/v5.22.2/crds.yaml`
  - Gateway API ([See Envoy Compatibility Matrix](https://gateway.envoyproxy.io/news/releases/matrix/)): `kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/experimental-install.yaml`
2. Install Cilium:
  - `kustomize build --enable-helm infrastructure/network/cilium | kubectl apply --server-side -f -`
  - `kubectl apply --server-side -f infrastructure/network/cilium/CiliumL2AnnouncementPolicy.yaml -f infrastructure/network/cilium/CiliumLoadBalancerIPPool.yaml`
3. Install Envoy Gateway:
  - `kustomize build --enable-helm infrastructure/network/envoy-gateway | kubectl apply --server-side -f -`
  - `kubectl apply --server-side -f infrastructure/network/envoy-gateway/EnvoyProxy.yaml -f infrastructure/network/envoy-gateway/GatewayClass.yaml`
4. Install Sealed Secrets:
  - `kubectl apply --server-side -f infrastructure/controllers/sealed-secrets/Namespace.yaml -f infrastructure/controllers/sealed-secrets/Secret.certs.yaml`
  - `kustomize build --enable-helm infrastructure/controllers/sealed-secrets | kubectl apply --server-side -f -`
5. Install cert-manager and trust-manager:
  - `kustomize build --enable-helm infrastructure/controllers/cert-manager | kubectl apply --server-side -f -`
  - `kubectl apply --server-side -f infrastructure/controllers/cert-manager/ClusterIssuer.le.yaml`
  - `cmctl -n cert-manager approve trust-manager-1`
  - `cmctl -n cert-manager approve trust-domain-root-ca-1`
6. Set up Gateway:
  - (Optional: restore saved certificates) `kubectl apply --server-side -f infrastructure/network/gateway/Namespace.yaml; for f in infrastructure/network/gateway/Secret.*-certificate.yaml; do kubectl apply --server-side -f "$f"; done`
  - `kubectl apply --server-side -k infrastructure/network/gateway`
7. Install ArgoCD:
  - `kustomize build --enable-helm infrastructure/controllers/argocd | kubectl apply --server-side -f -`
8.  Deploy infrastructure and applications:
  - `kubectl apply --server-side -k infrastructure`
  - `kubectl apply --server-side -k sets`

# Cheat sheet

Kube overview:
- `watch -n 5 kubectl get nodes -o wide`
- `watch -n 5 kubectl get deployments -o wide -A`
- `watch -n 5 kubectl get pods -o wide -A`
- `watch -n 5 kubectl get svc -o wide -A`

View resource usage:
  - Per pod:
    + `watch -n 5 kubectl top pods --sort-by=memory -A`
    + `watch -n 5 kubectl top pods --sort-by=cpu -A`
  - Per container:
    + `watch -n 5 kubectl top pod --sort-by=memory --containers -A`
    + `watch -n 5 kubectl top pod --sort-by=cpu --containers -A`
  - Per node:
    + `watch -n 5 kubectl top node --sort-by=memory`
    + `watch -n 5 kubectl top node --sort-by=cpu`

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
