echo "plain uncompressed text" > "$HOME/incident/var/log/app.log.1.gz"
truncate -s 0 "$HOME/incident/var/log/app.log"
