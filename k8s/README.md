# Bootstrap

1. Set up Cilium IP pool:
  - `kubectl apply -f infrastructure/network/cilium/CiliumL2AnnouncementPolicy.yaml -f infrastructure/network/cilium/CiliumLoadBalancerIPPool.yaml`
2. Install Envoy Gateway and set up GatewayClass:
  - `helm install envoy-gateway oci://docker.io/envoyproxy/gateway-helm --version v1.7.0 --namespace envoy-gateway-system --create-namespace -f infrastructure/network/envoy-gateway/values.yaml`
  - `kubectl apply -f infrastructure/network/envoy-gateway/EnvoyProxy.yaml -f infrastructure/network/envoy-gateway/GatewayClass.yaml`
3. Install cert-manager and set up a ClusterIssuer:
  - `helm install cert-manager oci://quay.io/jetstack/charts/cert-manager --version v1.19.3 --namespace cert-manager --create-namespace -f infrastructure/controllers/cert-manager/values.yaml`
  - `kubectl apply -f infrastructure/controllers/cert-manager/Secret.cloudflare-api-token.yaml -f infrastructure/controllers/cert-manager/ClusterIssuer.yaml`
4. Set up Gateway:
  - `kubectl apply -k infrastructure/network/gateway`
5. Install ArgoCD and provide it with the sops/age secret:
  - `kustomize build --enable-helm --enable-alpha-plugins --enable-exec infrastructure/controllers/argocd | kubectl apply --server-side -f -; cat "$XDG_CONFIG_HOME/sops/age/keys.txt" | kubectl create secret generic sops-age -n argocd --from-file=keys.txt=/dev/stdin`
6.  Deploy infrastructure and applications:
  - `kubectl apply -k infrastructure`
  - `kubectl apply -k sets`

# Cheat sheet

Kube overview:
- `watch -n 1 kubectl get nodes -o wide`
- `watch -n 1 kubectl get deployments -o wide -A`
- `watch -n 1 kubectl get pods -o wide -A`
- `watch -n 1 kubectl get svc -o wide -A`

Force delete namespace:
- `kubectl delete all --all -n {namespace}`
- `kubectl delete namespace {namespace}`

Clean up failede pods:
- `kubectl delete -A pods --field-selector status.phase=Failed`

Run debug container on node ([siderolabs.com](https://www.siderolabs.com/blog/how-to-ssh-into-talos-linux/)):
- `kubectl debug -n kube-system -it --image alpine:edge node/w01`
- `apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing igt-gpu-tools pciutils`

Open container shell:
- `kubectl -n MY_NAMESPACE exec -it pods/MY_POO_ID -c MY_CONTAINER -- /bin/bash`

Copy files to a container:
- `kubectl -n MY_NAMESPACE cp ./ MY_DEPLOYMENT:MY_PATH -c MY_CONTAINER`

# To do:

- Use VLAN for virtual machines and virtual IP
- Set up OIDC on gateways / httproutes
- Separate private from public services

# Projects to test

- Invidious
- Viewtube
