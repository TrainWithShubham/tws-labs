mkdir -p app
[ -f app/monitoring-ns.yaml ] || cat <<'EOF' > app/monitoring-ns.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  namespace: default
EOF

[ -f app/app-config.yaml ] || cat <<'EOF' > app/app-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  APP_ENV: development
  LOG_LEVEL: debug
EOF

