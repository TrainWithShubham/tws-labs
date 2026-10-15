sleep 300 & echo $! > force-sleep.pid
kill "$(cat force-sleep.pid)"
