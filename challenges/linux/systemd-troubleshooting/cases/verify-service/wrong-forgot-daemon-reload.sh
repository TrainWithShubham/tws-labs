INC_DIR="${LAB_HOME:-$HOME}/lnx-ch-040/incident"
(
  cd "$INC_DIR"
  ./bin/systemctl restart report-api.service || true
  ./bin/service-audit || true
)
