. "$LAB_LIB"
[ -s sleep.pid ] || fail "Start sleep 300 and save its PID in sleep.pid."
pid=$(cat sleep.pid)
ps -p "$pid" -o stat=,comm= |
  awk '$1 !~ /^Z/ && $2 == "sleep" { found=1 } END { exit !found }' ||
  fail "The recorded sleep process is not running."
