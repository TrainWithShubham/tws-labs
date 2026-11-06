INC_DIR="${LAB_HOME:-$HOME}/lnx-ch-040/incident"
sed -i 's/^Restart=no/Restart=on-failure/' "$INC_DIR/systemd/system/report-api.service"
# Leaves PORT=80 in config/report-api.env
