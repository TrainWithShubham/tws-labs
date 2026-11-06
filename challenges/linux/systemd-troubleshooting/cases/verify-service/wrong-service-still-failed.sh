INC_DIR="${LAB_HOME:-$HOME}/lnx-ch-040/incident"
(
  cd "$INC_DIR"
  sed -i 's/^PORT=8080/PORT=80/' config/report-api.env
  ./bin/systemctl daemon-reload
  ./bin/systemctl restart report-api.service || true
  ./bin/service-audit || true
)
