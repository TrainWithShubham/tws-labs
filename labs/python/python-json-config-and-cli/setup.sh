# A sample config to read: shared defaults plus per-environment overrides.
mkdir -p configs
cat > configs/app.json <<'EOF'
{
  "app": "shop",
  "defaults": {"port": 8080, "debug": false, "workers": 2, "log_level": "info"},
  "environments": {
    "dev": {"debug": true, "log_level": "debug"},
    "prod": {"workers": 8, "port": 80}
  }
}
EOF
printf '{\n  "defaults": {"port": 8080}\n}\n' > configs/broken.json
