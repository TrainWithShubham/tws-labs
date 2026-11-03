#!/bin/bash
mkdir -p config .fixtures
if [ ! -f config/app.template ]; then
  cat << 'EOF' > config/app.template
# Application configuration template
PORT=80
HOST=127.0.0.1
LOG_LEVEL=INFO
WORKERS=2
TOKEN_FILE=config/auth.token
EOF
fi
