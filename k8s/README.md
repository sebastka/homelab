# Bootstrap

1. First, make sure Gateway API CRDs are installed.
2. Install Cilium: `kubectl kustomize --enable-helm infrastructure/network/cilium | kubectl apply --server-side -f -`
3. Install Envoy Gateway: `helm install envoy-gateway oci://docker.io/envoyproxy/gateway-helm --version v1.6.2 -n envoy-gateway-system --create-namespace -f infrastructure/network/envoy-gateway/values.yaml`
4. Install cert-manager: `kubectl kustomize --enable-helm infrastructure/controllers/cert-manager | kubectl apply --server-side -f -`
5. Set up Gateway with Cloudflare DNS01 Issuer: `kustomize build --enable-helm --enable-alpha-plugins --enable-exec infrastructure/network/gateway | kubectl apply --server-side -f -`
6. Install ArgoCD and provide it with the sops/age secret: `kustomize build --enable-helm --enable-alpha-plugins --enable-exec infrastructure/controllers/argocd | kubectl apply --server-side -f -; cat "$XDG_CONFIG_HOME/sops/age/keys.txt" | kubectl create secret generic sops-age -n argocd --from-file=keys.txt=/dev/stdin`
7.  Deploy infrastructure and applications:
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
- `kubectl debug -n kube-system -it --image alpine:edge node/tw01`
- `apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing igt-gpu-tools pciutils`

Open container sheel:
- `kubectl -n MY_NAMESPACE exec -it pods/MY_POO_ID -c MY_CONTAINER -- /bin/bash`

Copy files to a container:
- `kubectl -n MY_NAMESPACE cp ./ MY_DEPLOYMENT:MY_PATH -c MY_CONTAINER`

# To do:

- Fix pod security for install-ksops
- Pass real client ip to pods
- Figure out global headers using Gateway API

# Projects to test

- Invidious
- Viewtube
