# yaml-language-server: $schema=https://raw.githubusercontent.com/siderolabs/talos/refs/heads/release-1.14/website/content/v1.14/schemas/config.schema.json
# Install disk, instead of the VMs' /dev/sda (all/00-install.yaml): pinned by serial
# (nodes[].data.installDisk in topf.yaml), so that adding NVMe drives later can never move the
# install. `talosctl get disks` shows the serial.
---
apiVersion: v1alpha1
kind: UnattendedInstallConfig
provisioning:
  diskSelector:
    match: disk.serial == "{{ .Node.Data.installDisk }}"
