#!/bin/bash
set -euo pipefail

mkdir -p "$HOME/access/projects/backend" "$HOME/access/config" "$HOME/access/sudoers.d"

# 1. Team directory with mode 0755 (group cannot write)
chmod 0755 "$HOME/access/projects/backend"

# 2. Defective group membership
cat << 'EOF' > "$HOME/access/config/group-membership.conf"
admin:wheel
operator:ops
deploy-agent:guest
EOF
chmod 0644 "$HOME/access/config/group-membership.conf"

# 3. Defective sudoers policy
cat << 'EOF' > "$HOME/access/sudoers.d/deploy-agent"
# Automated deployment runner privileges
deploy-agent ALL=(ALL) NOPASSWD: ALL
EOF
chmod 0644 "$HOME/access/sudoers.d/deploy-agent"

# 4. Clean up any prior marker
rm -f "$HOME/access/.access-audit.passed"

# 5. Verification tool
cat << 'VERIFY_EOF' > "$HOME/access/verify-access"
#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

# Verify directory permissions
mode=$(stat -c '%a' "projects/backend" 2>/dev/null || stat -f '%Lp' "projects/backend" 2>/dev/null)
if [ "$mode" != "775" ]; then
  echo "FAIL: projects/backend mode is $mode (expected 775)." >&2
  exit 1
fi

# Verify group membership mapping
if ! grep -Eq "^deploy-agent:engineers$" config/group-membership.conf; then
  echo "FAIL: config/group-membership.conf does not map deploy-agent to engineers." >&2
  exit 1
fi

# Verify sudo policy restriction
if ! grep -Eq "^deploy-agent[[:space:]]+ALL=\(ALL\)[[:space:]]+NOPASSWD:[[:space:]]*/usr/bin/systemctl restart app$" sudoers.d/deploy-agent; then
  echo "FAIL: sudoers.d/deploy-agent does not restrict command execution to /usr/bin/systemctl restart app." >&2
  exit 1
fi

cat << 'MARKER_EOF' > ".access-audit.passed"
{
  "status": "PASSED",
  "verified_at": "2026-11-05T12:00:00Z",
  "audit": "users-groups-access"
}
MARKER_EOF

echo "SUCCESS: Access control and group policies verified successfully."
exit 0
VERIFY_EOF
chmod 0755 "$HOME/access/verify-access"
