#!/bin/bash
mkdir -p app

cat <<'EOF' > app/deploy-manager-role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deployment-manager
  namespace: development
rules:
  - apiGroups:
      - ""
    resources:
      - deployments
    verbs:
      - get
      - list
      - watch
      - create
EOF
