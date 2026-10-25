# DHCP on the node's main link: bond0 on the NUC 16s, lan0 on hera (see topf.yaml).
---
apiVersion: v1alpha1
kind: DHCPv4Config
name: {{ .Node.Data.link }}
