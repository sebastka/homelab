# Topology labels.
---
apiVersion: v1alpha1
kind: KubeNodeConfig
labels:
  topology.kubernetes.io/region: {{ .ClusterName }}
  topology.kubernetes.io/zone: {{ .Node.Data.zone }}
