mkdir -p app

[ -f app/app-viewer-sa.yaml ] || cat <<'EOF' > app/app-viewer-sa.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-viewer
  namespace: development
EOF
