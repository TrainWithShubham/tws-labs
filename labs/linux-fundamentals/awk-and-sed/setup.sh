#!/bin/bash
set -e

mkdir -p web-server .fixtures

cat <<'EOF' > web-server/access.log
192.168.1.10 - - [10/Oct/2026:13:55:36 +0000] "GET /index.html HTTP/1.1" 200 2326
10.0.0.15 - - [10/Oct/2026:13:55:37 +0000] "POST /api/login HTTP/1.1" 500 524
192.168.1.12 - - [10/Oct/2026:13:55:38 +0000] "GET /app.js HTTP/1.1" 200 1204
172.16.0.5 - - [10/Oct/2026:13:55:39 +0000] "GET /api/checkout HTTP/1.1" 500 524
10.0.0.15 - - [10/Oct/2026:13:55:40 +0000] "GET /favicon.ico HTTP/1.1" 404 153
192.168.1.20 - - [10/Oct/2026:13:55:41 +0000] "GET /products HTTP/1.1" 200 4502
172.16.0.8 - - [10/Oct/2026:13:55:42 +0000] "POST /api/payment HTTP/1.1" 500 524
10.0.0.22 - - [10/Oct/2026:13:55:43 +0000] "GET /images/logo.png HTTP/1.1" 200 8920
192.168.1.10 - - [10/Oct/2026:13:55:44 +0000] "GET /contact HTTP/1.1" 200 1845
10.0.0.30 - - [10/Oct/2026:13:55:45 +0000] "POST /api/orders HTTP/1.1" 500 524
EOF

cat <<'EOF' > web-server/nginx.conf
server {
    listen 80;
    server_name example.internal;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
    }
}
EOF

cat <<'EOF' > web-server/debug.log
[2026-10-10 13:55:36] INFO user logged in session_id=abc123
[2026-10-10 13:55:37] ERROR payment failed api_key=sk994829104859 client_id=c10
[2026-10-10 13:55:38] DEBUG cache refresh completed entries=42
[2026-10-10 13:55:39] WARN auth retry with api_key=testkey987654 user=admin
[2026-10-10 13:55:40] INFO route not found path=/favicon.ico
[2026-10-10 13:55:42] ERROR upstream timeout api_key=prod88371928472 retry=3
EOF

cp web-server/access.log .fixtures/access.log
cp web-server/nginx.conf .fixtures/nginx.conf
cp web-server/debug.log .fixtures/debug.log

chmod 755 .fixtures
chmod 444 .fixtures/*