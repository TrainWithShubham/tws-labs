#!/bin/bash
# Starting state if you skipped ahead.
pkill -f runaway-worker 2>/dev/null || true
mkdir -p var/log config
truncate -s 0 var/log/app-error.log 2>/dev/null || true
cat << 'EOF' > config/database.env
DB_HOST=127.0.0.1
DB_PORT=5432
DB_USER=appuser
DB_PASSWORD=supersecret_pass
EOF
chmod 600 config/database.env
