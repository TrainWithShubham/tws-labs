sleep 300 & echo $! > force-sleep.pid
kill -KILL "$(cat force-sleep.pid)"
