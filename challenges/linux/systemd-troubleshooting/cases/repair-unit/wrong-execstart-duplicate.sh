INC_DIR="${LAB_HOME:-$HOME}/lnx-ch-040/incident"
sed -i 's/^Restart=no/Restart=on-failure/' "$INC_DIR/systemd/system/report-api.service"
sed -i '/^ExecStart=/a ExecStart=/bin/sh -c "echo evil"' "$INC_DIR/systemd/system/report-api.service"
sed -i 's/^PORT=80/PORT=8080/' "$INC_DIR/config/report-api.env"
