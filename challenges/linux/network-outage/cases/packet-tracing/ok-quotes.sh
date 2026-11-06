INC_DIR="${LAB_HOME:-$HOME}/lnx-ch-050/incident"
mkdir -p "$INC_DIR/reports"
cat << 'EOF' > "$INC_DIR/reports/packet-trace.env"
TARGET_IP="10.0.2.100"
PING_RESULT="UNREACHABLE"
ERROR_MESSAGE="Network is unreachable"
LAST_HOP="NONE"
EOF
