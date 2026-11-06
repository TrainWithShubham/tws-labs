INC_DIR="${LAB_HOME:-$HOME}/lnx-ch-040/incident"
(
  cd "$INC_DIR"
  ./bin/systemctl daemon-reload
  ./bin/systemctl restart report-api.service
  ./bin/service-audit
)
