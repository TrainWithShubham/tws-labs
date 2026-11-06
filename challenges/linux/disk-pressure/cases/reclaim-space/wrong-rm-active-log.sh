gzip -c "$HOME/incident/var/log/app.log" > "$HOME/incident/var/log/app.log.1.gz"
rm -f "$HOME/incident/var/log/app.log"
