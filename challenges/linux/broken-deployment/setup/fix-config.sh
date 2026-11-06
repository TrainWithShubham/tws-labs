#!/bin/bash
# Starting state if skipped ahead to fix-config.
set -e
mkdir -p "$HOME/deploy/bin" "$HOME/deploy/config" "$HOME/deploy/hooks" "$HOME/deploy/reports"
if [ ! -f "$HOME/deploy/bin/app-cli-v2" ]; then
  cat << 'EOF' > "$HOME/deploy/bin/app-cli-v2"
#!/bin/bash
echo "app-cli-v2: release runtime ready"
exit 0
EOF
  chmod 0755 "$HOME/deploy/bin/app-cli-v2"
fi
ln -sf app-cli-v2 "$HOME/deploy/bin/app-cli"
if [ ! -f "$HOME/deploy/config/app.env" ]; then
  cat << 'EOF' > "$HOME/deploy/config/app.env"
# Gateway Production Configuration
APP_NAME=payment-gateway
APP_ENV="production
APP_PORT = 8080
DB_TIMEOUT=30
EOF
  chmod 0644 "$HOME/deploy/config/app.env"
fi
