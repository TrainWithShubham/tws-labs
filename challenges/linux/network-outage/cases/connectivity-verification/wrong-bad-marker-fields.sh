INC_DIR="${LAB_HOME:-$HOME}/lnx-ch-050/incident"
mkdir -p "$INC_DIR/reports"
cat << 'EOF' > "$INC_DIR/reports/audit-success.marker"
NETWORK_STATUS=FAILED
CLIENT_IP=10.0.1.10
ACTIVE_GATEWAY=none
TARGET_REACHABLE=false
EOF
