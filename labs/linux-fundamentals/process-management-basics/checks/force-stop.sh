. "$LAB_LIB"
[ -s force-sleep.pid ] || fail "Start a process and save its PID in force-sleep.pid."
ran_re '(^|[;&|[:space:](])(kill|pkill|killall)[[:space:]]+(-9|-KILL|-SIGKILL|-s[[:space:]]+(9|KILL|SIGKILL))([[:space:]]|$)' || fail "Use kill -9 (SIGKILL) to force-stop the process."
pid=$(cat force-sleep.pid)
if ps -p "$pid" -o stat=,comm= |
  awk '$1 !~ /^Z/ && $2 == "sleep" { found=1 } END { exit !found }'
then
  fail "Force-stop the recorded process using kill -9."
fi
