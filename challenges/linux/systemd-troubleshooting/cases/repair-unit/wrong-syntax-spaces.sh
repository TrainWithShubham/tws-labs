INC_DIR="${LAB_HOME:-$HOME}/lnx-ch-040/incident"
sed -i 's/^Restart=no/Restart=on-failure/' "$INC_DIR/systemd/system/report-api.service"
cat << 'EOF' > "$INC_DIR/config/report-api.env"
APP_ENV=production
PORT = 8080
DB_POOL=10
LOG_LEVEL=INFO
EOF
