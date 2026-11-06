INC_DIR="${LAB_HOME:-$HOME}/lnx-ch-040/incident"
(
  cd "$INC_DIR"
  ./bin/systemctl daemon-reload
  # Modify env file formatting/comment (env changes without touching unit file)
  echo "# Reload test comment" >> config/report-api.env
  # Restart service directly without another daemon-reload
  ./bin/systemctl restart report-api.service
  ./bin/service-audit
)
