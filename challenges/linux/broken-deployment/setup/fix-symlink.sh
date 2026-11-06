#!/bin/bash
# Starting state if skipped ahead to fix-symlink.
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
[ -L "$HOME/deploy/bin/app-cli" ] || ln -sf "/opt/legacy-app/v1/bin/app-cli" "$HOME/deploy/bin/app-cli"
