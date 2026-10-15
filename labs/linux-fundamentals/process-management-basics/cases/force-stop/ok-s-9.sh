sleep 300 & echo $! > force-sleep.pid
kill -s 9 "$(cat force-sleep.pid)"
