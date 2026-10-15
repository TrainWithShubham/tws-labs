. "$LAB_LIB"

[ -f app.pid ] || fail "app.pid not found. Run ./start.sh to launch the service."

pid=$(cat app.pid 2>/dev/null)
[ -n "$pid" ] || fail "app.pid is empty."

if [ ! -d "/proc/$pid" ]; then
  fail "Process $pid recorded in app.pid is not running."
fi
