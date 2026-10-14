sleep 300 & echo $! > force-sleep.pid
kill -9 "$(cat force-sleep.pid)"
