INC_DIR="${LAB_HOME:-$HOME}/lnx-ch-040/incident"
sed -i 's/^PORT=80/PORT=8080/' "$INC_DIR/config/report-api.env"
# Leaves Restart=no in systemd/system/report-api.service
