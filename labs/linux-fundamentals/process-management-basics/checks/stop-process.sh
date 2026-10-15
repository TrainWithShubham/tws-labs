. "$LAB_LIB"
[ -s sleep.pid ] || fail "Cannot find sleep.pid."
ran_re '(^|[;&|(][[:space:]]*)(kill|pkill|killall)([[:space:]]|$)' || fail "Stop the process with the kill command (pkill works too)."
pid=$(cat sleep.pid)
if ps -p "$pid" -o stat=,comm= |
  awk '$1 !~ /^Z/ && $2 == "sleep" { found=1 } END { exit !found }'
then
  fail "Stop the process using kill and the PID in sleep.pid."
fi
