printf '\x1f\x8b\x08\x00corrupt' > "$HOME/incident/var/log/app.log.1.gz"
truncate -s 0 "$HOME/incident/var/log/app.log"
