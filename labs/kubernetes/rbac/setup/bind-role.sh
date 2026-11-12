mkdir -p app

[ -f app/app-viewer-sa.yaml ] || cat <<'EOF' > app/app-viewer-sa.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-viewer
  namespace: development
EOF

[ -f app/pod-reader-role.yaml ] || cat <<'EOF' > app/pod-reader-role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: development
rules:
  - apiGroups: [""]
    resources: ["pods", "configmaps"]
    verbs: ["get", "list", "watch"]
EOF
