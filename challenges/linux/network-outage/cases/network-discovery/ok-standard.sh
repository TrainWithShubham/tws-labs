INC_DIR="${LAB_HOME:-$HOME}/lnx-ch-050/incident"
mkdir -p "$INC_DIR/reports"
cat << 'EOF' > "$INC_DIR/reports/discovery.env"
CLIENT_IP=10.0.1.10
DNS_SERVER=10.0.2.53
RESOLVED_IP=10.0.2.100
DNS_STATUS=RESOLVED
EOF
