#!/bin/bash
set -euo pipefail

if [ -d "$HOME/deploy/cache" ]; then
  chmod 0755 "$HOME/deploy/cache" 2>/dev/null || true
fi
mkdir -p "$HOME/deploy/scripts" "$HOME/deploy/config" "$HOME/deploy/cache"

# 1. Backup script without execute bit (0644)
cat << 'EOF' > "$HOME/deploy/scripts/backup.sh"
#!/bin/bash
echo "[BACKUP] Maintenance backup archive generated successfully."
exit 0
EOF
chmod 0644 "$HOME/deploy/scripts/backup.sh"

# 2. Database credentials with world permissions (0666)
cat << 'EOF' > "$HOME/deploy/config/db-credentials.env"
DB_HOST=127.0.0.1
DB_PORT=5432
DB_USER=app_admin
DB_PASSWORD=supersecret_production_password
EOF
chmod 0666 "$HOME/deploy/config/db-credentials.env"

# 3. Cache directory without execute bit (0644 on dir)
chmod 0755 "$HOME/deploy/cache"
cat << 'EOF' > "$HOME/deploy/cache/ready.flag"
READY=1
EOF
chmod 0644 "$HOME/deploy/cache/ready.flag"
chmod 0644 "$HOME/deploy/cache"

# 4. Remove any prior marker
rm -f "$HOME/deploy/.permissions-audit.passed"

# 5. Verification tool
cat << 'VERIFY_EOF' > "$HOME/deploy/verify-permissions"
#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

# Check script executable
if [ ! -x "scripts/backup.sh" ]; then
  echo "FAIL: scripts/backup.sh is not executable." >&2
  exit 1
fi

# Check credentials mode 0600
mode=$(stat -c '%a' "config/db-credentials.env" 2>/dev/null || stat -f '%Lp' "config/db-credentials.env" 2>/dev/null)
if [ "$mode" != "600" ]; then
  echo "FAIL: config/db-credentials.env mode is $mode (expected 600)." >&2
  exit 1
fi

# Check cache directory traversable
if [ ! -r "cache/ready.flag" ]; then
  echo "FAIL: cache/ready.flag is not readable (check directory execute permissions)." >&2
  exit 1
fi

cat << 'MARKER_EOF' > ".permissions-audit.passed"
{
  "status": "PASSED",
  "verified_at": "2026-11-05T12:00:00Z",
  "audit": "file-directory-permissions"
}
MARKER_EOF

echo "SUCCESS: All file and directory permission audits passed."
exit 0
VERIFY_EOF
chmod 0755 "$HOME/deploy/verify-permissions"
