# Each learner gets their own port and their own stand-in "model" (a scripted server, not a real model: see support/stand-in.js).
lab_dir=$(cd "$(dirname "$0")" && pwd)
busy() { grep -qiE "^ *[0-9]+: [0-9A-F]+:$(printf '%04X' "$1") " /proc/net/tcp /proc/net/tcp6 2>/dev/null; }
while :; do
  p=$((20000 + (RANDOM << 15 | RANDOM) % 12000))
  busy "$p" || break
done
echo "$p" > port.txt
printf 'line %d\n' 1 2 3 4 5 6 7 > notes.txt
printf 'task %d\n' 1 2 3 4 > todo.txt
setsid nohup python3 "$lab_dir/support/stand_in.py" "$p" > /dev/null 2>&1 < /dev/null &
for _ in $(seq 1 60); do busy "$p" && break; sleep 0.05; done
