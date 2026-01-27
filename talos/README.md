# Talos bootstrap

Run: `./init.sh`

# Cheat sheet

Watch nodes:
- `talosctl get members --watch`

Edit machine config:
- `talosctl -n 192.168.6.201 edit machineconfig`

Reboot all:
- `talosctl reboot --nodes 192.168.6.201,192.168.6.211,192.168.6.214`
- `talosctl reboot --nodes 192.168.6.202,192.168.6.212,192.168.6.215`
- `talosctl reboot --nodes 192.168.6.203,192.168.6.213,192.168.6.216`
