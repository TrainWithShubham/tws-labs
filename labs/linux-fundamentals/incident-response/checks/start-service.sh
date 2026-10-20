. "$LAB_LIB"

[ -f app.pid ] || fail "app.pid not found. Run ./start.sh to launch the service."

pid=$(cat app.pid 2>/dev/null)
[ -n "$pid" ] || fail "app.pid is empty."

ps -p "$pid" -o stat=,args= 2>/dev/null |
  awk '$1 !~ /^Z/ && $2 == "api-service" { found=1 } END { exit !found }' ||
  fail "No api-service process is running with the PID in app.pid. Run ./start.sh."
ran_re '(^|[;&|(][[:space:]]*)((ba)?sh[[:space:]]+)?(\./|bin/)?start\.sh' || fail "Launch the service with ./start.sh."
