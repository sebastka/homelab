# OIDC configuration for api server
# - https://kubernetes.io/docs/reference/access-authn-authz/authentication/
#
# v1.14: kube-apiserver rejects every --oidc-* flag once --authentication-config is set, and
# Talos always sets it, so the flags move into KubeAuthenticationConfig as structured
# authentication configuration. The generated document already carries the `anonymous` block
# and an empty `jwt` list; only `jwt` is replaced here.
---
apiVersion: v1alpha1
kind: KubeAuthenticationConfig
configuration:
  jwt:
    - issuer:
        url: {{ .Data.oidcIssuerUrl }}
        audiences: ['{{ .Data.oidcClientId }}']
      claimMappings:
        username:
          claim: email
          prefix: 'authelia:'
        groups:
          claim: groups
          prefix: 'authelia:'
      # claimValidationRules: [{claim: XX, requiredValue: YY}]
