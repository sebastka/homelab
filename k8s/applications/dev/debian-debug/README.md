# debian-debug

Test deployment with multiple purposes.

## Test Velero backups from S3:

1. Restore PVC:
```
velero restore create paperless-test-restore \
    --from-backup velero-test-hetzner-20260502200032 \
    --include-namespaces paperless \
    --include-resources persistentvolumeclaims \
    --namespace-mappings paperless:debian-debug
```

2. Watch progress: `kubectl get datadownload -n velero -w`
