INC_DIR="${LAB_HOME:-$HOME}/lnx-ch-040/incident"
sed -i 's/^Restart=no/Restart=on-failure/' "$INC_DIR/systemd/system/report-api.service"
sed -i 's|^ExecStart=.*|ExecStart=%h/lnx-ch-040/incident/bin/report-api-fake --mode=production|' "$INC_DIR/systemd/system/report-api.service"
sed -i 's/^PORT=80/PORT=8080/' "$INC_DIR/config/report-api.env"
