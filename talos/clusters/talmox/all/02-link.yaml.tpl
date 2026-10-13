# DHCP on the node's main link: eth0 on the VMs, bond0 on the NUCs (see topf.yaml).
---
apiVersion: v1alpha1
kind: DHCPv4Config
name: {{ .Node.Data.link }}
