# Matrix Authentication Service

Generate a registration token:
```
kubectl exec -n matrix-authentication-service deploy/matrix-authentication-service -- \
    mas-cli --config /config/config.yaml manage issue-user-registration-token
```
