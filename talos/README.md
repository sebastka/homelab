# Talos bootstrap

Run: `./init.sh`

# Cheat sheet

Watch nodes:
- `talosctl get members --watch`

Edit machine config:
- `talosctl -n 192.168.1.201 edit machineconfig`

Apply machineconfig patch:
- `talosctl patch machineconfig --patch-file patch/X/Y.yaml --nodes 192.168.1.201`

Reboot all:
- `talosctl reboot --nodes 192.168.1.201,192.168.1.211`
- `talosctl reboot --nodes 192.168.1.202,192.168.1.212`
- `talosctl reboot --nodes 192.168.1.203,192.168.1.213`
