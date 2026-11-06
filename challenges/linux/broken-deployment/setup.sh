#!/bin/bash
set -e

mkdir -p "$HOME/deploy/bin" "$HOME/deploy/config" "$HOME/deploy/hooks" "$HOME/deploy/reports"

# 1. Binary target and broken symlink
cat << 'EOF' > "$HOME/deploy/bin/app-cli-v2"
#!/bin/bash
echo "app-cli-v2: release runtime ready"
exit 0
EOF
chmod 0755 "$HOME/deploy/bin/app-cli-v2"
ln -sf "/opt/legacy-app/v1/bin/app-cli" "$HOME/deploy/bin/app-cli"

# 2. Corrupt config syntax
cat << 'EOF' > "$HOME/deploy/config/app.env"
# Gateway Production Configuration
APP_NAME=payment-gateway
APP_ENV="production
APP_PORT = 8080
DB_TIMEOUT=30
EOF
chmod 0644 "$HOME/deploy/config/app.env"

# 3. Hook without execute bit
cat << 'EOF' > "$HOME/deploy/hooks/pre-deploy.sh"
#!/bin/bash
set -e
[ -f "config/app.env" ] || exit 1
echo "[HOOK] Pre-deployment validation passed."
exit 0
EOF
chmod 0644 "$HOME/deploy/hooks/pre-deploy.sh"

# 4. Lock file
cat << 'EOF' > "$HOME/deploy/.deploy.lock"
{
  "status": "FAILED_PRE_FLIGHT",
  "failed_at": "2026-11-04T03:22:18Z",
  "reason": "Pre-flight checks aborted: broken binary link, malformed config, or unexecutable hooks",
  "action_required": "Resolve all pre-flight defects and run ./verify-deployment to clear recovery lock"
}
EOF
chmod 0644 "$HOME/deploy/.deploy.lock"

# 5. Log file
cat << 'EOF' > "$HOME/deploy/reports/deploy.log"
[03:22:15 UTC] Starting deployment run #4029...
[03:22:16 UTC] Error: bin/app-cli is a broken symlink (points to /opt/legacy-app/v1/bin/app-cli).
[03:22:16 UTC] Error: config/app.env failed syntax parsing.
[03:22:17 UTC] Error: hooks/pre-deploy.sh is not executable (permission denied).
[03:22:18 UTC] Fatal: Aborting deployment. Lock recorded at .deploy.lock.
EOF
chmod 0644 "$HOME/deploy/reports/deploy.log"

# 6. Verification tool (unprivileged, bounded, deterministic marker)
cat << 'VERIFY_SCRIPT_EOF' > "$HOME/deploy/verify-deployment"
#!/bin/bash
set -e
cd "$(dirname "$0")"

# 1. Stale lock check
if [ -f ".deploy.lock" ]; then
  echo "Error: .deploy.lock is still present. Resolve defects and remove lock file before re-verifying." >&2
  exit 1
fi

# 2. Symlink verification
if [ ! -L "bin/app-cli" ] || [ ! -e "bin/app-cli" ]; then
  echo "Error: bin/app-cli is not a valid, resolving symlink." >&2
  exit 2
fi
TARGET=$(readlink "bin/app-cli")
if [ "$TARGET" != "app-cli-v2" ] && [ "$TARGET" != "bin/app-cli-v2" ] && [ "$TARGET" != "$(pwd)/bin/app-cli-v2" ]; then
  echo "Error: bin/app-cli must point to app-cli-v2." >&2
  exit 2
fi

# 3. Safe configuration validation (strict parsing without sourcing)
declare -A seen_keys=()
while IFS= read -r line || [ -n "$line" ]; do
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ "$line" =~ ^[[:space:]]*$ ]] && continue

  if [[ "$line" =~ ^[^=]*[[:space:]]+= ]] || [[ "$line" =~ =[[:space:]]+ ]]; then
    echo "Error: Illegal whitespace around '=' in config/app.env: '$line'" >&2
    exit 3
  fi

  if ! [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
    echo "Error: Malformed variable assignment in config/app.env: '$line'" >&2
    exit 3
  fi

  key="${BASH_REMATCH[1]}"
  val="${BASH_REMATCH[2]}"

  if [[ "$val" =~ ^\" && ! "$val" =~ \"$ ]] || [[ "$val" =~ ^\' && ! "$val" =~ \'$ ]]; then
    echo "Error: Unclosed quotation in config/app.env for key '$key'" >&2
    exit 3
  fi

  clean_val="$val"
  if [[ "$clean_val" =~ ^\"(.*)\"$ ]] || [[ "$clean_val" =~ ^\'(.*)\'$ ]]; then
    clean_val="${BASH_REMATCH[1]}"
  fi

  if [[ -n "${seen_keys[$key]}" ]]; then
    echo "Error: Duplicate configuration key '$key' in config/app.env" >&2
    exit 3
  fi
  seen_keys["$key"]="$clean_val"
done < "config/app.env"

for req_key in APP_NAME APP_ENV APP_PORT DB_TIMEOUT; do
  if [[ -z "${seen_keys[$req_key]}" ]]; then
    echo "Error: Missing required configuration key '$req_key' in config/app.env" >&2
    exit 3
  fi
done

[ "${seen_keys[APP_NAME]}" = "payment-gateway" ] || { echo "Error: APP_NAME must equal 'payment-gateway'" >&2; exit 3; }
[ "${seen_keys[APP_ENV]}" = "production" ] || { echo "Error: APP_ENV must equal 'production'" >&2; exit 3; }
[ "${seen_keys[APP_PORT]}" = "8080" ] || { echo "Error: APP_PORT must equal '8080'" >&2; exit 3; }
[ "${seen_keys[DB_TIMEOUT]}" = "30" ] || { echo "Error: DB_TIMEOUT must equal '30'" >&2; exit 3; }

# 4. Hook permission check and execution with 3-second bounded timeout
if [ ! -x "hooks/pre-deploy.sh" ]; then
  echo "Error: hooks/pre-deploy.sh is not executable." >&2
  exit 4
fi

set -m
./hooks/pre-deploy.sh >/dev/null 2>&1 &
HOOK_PID=$!
HOOK_PGID=$(ps -o pgid= -p "$HOOK_PID" 2>/dev/null | tr -d '[:space:]')
[ -n "$HOOK_PGID" ] || HOOK_PGID="$HOOK_PID"

(
  sleep 3
  kill -TERM -"$HOOK_PGID" 2>/dev/null || true
  sleep 0.5
  kill -KILL -"$HOOK_PGID" 2>/dev/null || true
) &
WATCHDOG_PID=$!

if ! wait "$HOOK_PID" 2>/dev/null; then
  kill -KILL "$WATCHDOG_PID" 2>/dev/null || true
  kill -KILL -"$HOOK_PGID" 2>/dev/null || true
  set +m
  echo "Error: hooks/pre-deploy.sh failed or timed out after 3 seconds." >&2
  exit 4
fi

kill -KILL "$WATCHDOG_PID" 2>/dev/null || true
set +m

# 5. Deterministic verification marker generation
cat << 'MARKER_EOF' > "reports/deploy-verification.status"
DEPLOYMENT_STATE=VERIFIED
COMPONENTS=APP_CLI:APP_ENV:PRE_DEPLOY_HOOK
TARGET_REVISION=v2
VERIFIED_BY=local_preflight
MARKER_EOF

echo "Deployment verified successfully."
exit 0
VERIFY_SCRIPT_EOF
chmod 0755 "$HOME/deploy/verify-deployment"
