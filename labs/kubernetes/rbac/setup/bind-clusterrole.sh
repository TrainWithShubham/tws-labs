mkdir -p app

[ -f app/app-viewer-sa.yaml ] || cat <<'EOF' > app/app-viewer-sa.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-viewer
  namespace: development
EOF

[ -f app/node-viewer-clusterrole.yaml ] || cat <<'EOF' > app/node-viewer-clusterrole.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-viewer
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list"]
EOF
