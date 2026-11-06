INC_DIR="${LAB_HOME:-$HOME}/lnx-ch-040/incident"
mkdir -p "$INC_DIR/reports"
cat << 'EOF' > "$INC_DIR/reports/journal-triage.env"
ERROR_SIGNATURE=ERR_PRIVILEGED_PORT
CONFIG_SOURCE=config/report-api.env
REJECTED_PORT=443
ROOT_CAUSE=UNPRIVILEGED_PORT_VIOLATION
EOF
