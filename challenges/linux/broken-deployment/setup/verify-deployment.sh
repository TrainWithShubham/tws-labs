#!/bin/bash
# Starting state if skipped ahead to verify-deployment.
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
cat << 'EOF' > "$HOME/deploy/config/app.env"
# Gateway Production Configuration
APP_NAME=payment-gateway
APP_ENV=production
APP_PORT=8080
DB_TIMEOUT=30
EOF
chmod 0644 "$HOME/deploy/config/app.env"
cat << 'EOF' > "$HOME/deploy/hooks/pre-deploy.sh"
#!/bin/bash
set -e
[ -f "config/app.env" ] || exit 1
echo "[HOOK] Pre-deployment validation passed."
exit 0
EOF
chmod 0755 "$HOME/deploy/hooks/pre-deploy.sh"
cat << 'EOF' > "$HOME/deploy/.deploy.lock"
{
  "status": "FAILED_PRE_FLIGHT"
}
EOF
chmod 0644 "$HOME/deploy/.deploy.lock"
rm -f "$HOME/deploy/reports/deploy-verification.status"
