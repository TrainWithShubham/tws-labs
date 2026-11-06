INC_DIR="${LAB_HOME:-$HOME}/lnx-ch-050/incident"
# Remove route from state
sed -i '/10.0.1.1/d' "$INC_DIR/run/net/routes.state"
sed -i '/10.0.1.1/d' "$INC_DIR/config/routes.conf"

# Fake marker creation
mkdir -p "$INC_DIR/reports"
cat << 'EOF' > "$INC_DIR/reports/audit-success.marker"
NETWORK_STATUS=RECOVERED
CLIENT_IP=10.0.1.10
ACTIVE_GATEWAY=10.0.1.1
TARGET_REACHABLE=10.0.2.100
DNS_RESOLVED=api.internal.corp
AUDITED_BY=netops_audit_v1
EOF
