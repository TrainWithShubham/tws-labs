gzip -c "$HOME/incident/var/log/app.log" > "$HOME/incident/var/log/app.log.1.gz"
truncate -s 0 "$HOME/incident/var/log/app.log"
