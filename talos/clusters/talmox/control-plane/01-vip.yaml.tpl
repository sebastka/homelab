# Shared control-plane VIP, matching clusterEndpoint in topf.yaml.
# https://docs.siderolabs.com/talos/v1.14/networking/advanced/vip
---
apiVersion: v1alpha1
kind: Layer2VIPConfig
name: {{ .Data.vip }}
link: {{ .Data.link }}
