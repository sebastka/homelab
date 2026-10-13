# Shared control-plane VIP, matching clusterEndpoint in topf.yaml.
# https://docs.siderolabs.com/talos/v1.14/networking/advanced/vip
#
# Announced on each node's main link. The VIP sits in 192.168.1.0/24 while the NUCs are
# 192.168.0.x, which works because the whole LAN is one /16.
---
apiVersion: v1alpha1
kind: Layer2VIPConfig
name: {{ .Data.vip }}
link: {{ .Node.Data.link }}
