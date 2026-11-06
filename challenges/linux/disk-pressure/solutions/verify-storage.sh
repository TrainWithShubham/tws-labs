sed -i 's/LOG_LEVEL=TRACE/LOG_LEVEL=WARN/' "$HOME/incident/config/service.conf"
printf '%s\n' "\"$(realpath "$HOME/incident/var/log/app.log")\" {" "    size 10M" "    rotate 5" "    compress" "    missingok" "    notifempty" "}" > "$HOME/incident/config/logrotate.conf"
(cd "$HOME/incident" && ./bin/storage-audit)
