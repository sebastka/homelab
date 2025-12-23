# Talos bootstrap

Run: `./init.sh`

## Cheat sheet

Kube overview:
- `watch -n 1 kubectl get nodes -o wide`
- `watch -n 1 kubectl get deployments -o wide -A`
- `watch -n 1 kubectl get pods -o wide -A`
- `watch -n 1 kubectl get svc -o wide -A`

Force delete namespace:
- `kubectl delete all --all -n {namespace}`
- `kubectl delete namespace {namespace}`

Edit machine config:
- `talosctl -n 192.168.6.201 edit machineconfig`

Reboot all:
- `talosctl reboot --nodes 192.168.6.201,192.168.6.211`
- `talosctl reboot --nodes 192.168.6.202,192.168.6.212`
- `talosctl reboot --nodes 192.168.6.203,192.168.6.213`
