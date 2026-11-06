INC_DIR="${LAB_HOME:-$HOME}/lnx-ch-040/incident"
mkdir -p "$INC_DIR/reports"
cat << 'EOF' > "$INC_DIR/reports/service-triage.env"
FAILED_SERVICE = report-api.service
ACTIVE_STATE = failed
SUB_STATE = failed
EXIT_STATUS = 1/FAILURE
EOF
