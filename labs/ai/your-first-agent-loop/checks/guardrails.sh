. "$LAB_LIB"
lab=$(cd "$(dirname "$0")/.." && pwd)
d=$(mktemp -d)
trap 'rm -rf "$d"' EXIT
busy() { grep -qiE "^ *[0-9]+: [0-9A-F]+:$(printf '%04X' "$1") " /proc/net/tcp /proc/net/tcp6 2>/dev/null; }
na=$((RANDOM % 5 + 2))   # different counts on every run, so a hard-coded answer cannot pass
nb=$((RANDOM % 5 + 8))
# mk_dir NAME MODE : a folder with two data files and its own stand-in model (it stops by itself after 15 seconds)
mk_dir() {
  mkdir -p "$d/$1"
  seq 1 "$na" | sed 's/^/a/' > "$d/$1/a.txt"
  seq 1 "$nb" | sed 's/^/b/' > "$d/$1/b.log"
  while :; do port=$((20000 + (RANDOM << 15 | RANDOM) % 12000)); busy "$port" || break; done
  _timeout 15 python3 "$lab/support/stand_in.py" "$port" "$2" >/dev/null 2>&1 &
  for _ in $(seq 1 60); do busy "$port" && break; sleep 0.05; done
  echo "$port" > "$d/$1/port.txt"
}
[ -f agent.py ] || fail "agent.py does not exist yet."
mk_dir normal normal
mk_dir flaky flaky
mk_dir endless endless
got=$(cd "$d/normal" && _timeout 6 python3 "$OLDPWD/agent.py" "how many lines are in a.txt and b.log?" 2>&1 | tail -n 1)
[ "$got" = "a.txt: $na, b.log: $nb. Total: $((na + nb)) lines." ] || fail "The agent no longer answers a normal question correctly (it ended with '${got:-nothing}')."
got=$(cd "$d/flaky" && _timeout 6 python3 "$OLDPWD/agent.py" "how many lines are in a.txt and b.log?" 2>&1 | tail -n 1)
[ "$got" = "a.txt: $na, b.log: $nb. Total: $((na + nb)) lines." ] || fail "When the model sent a broken tool call, the agent did not recover (it ended with '${got:-nothing}'). Tell the model about the error and carry on."
port=$(cat "$d/endless/port.txt")
(cd "$d/endless" && _timeout 6 python3 "$OLDPWD/agent.py" "how many lines are in a.txt and b.log?" >/dev/null 2>&1)
rc=$?
[ "$rc" != 124 ] || fail "When the model never gives an answer, the agent never stops. Give it a step limit."
[ "$rc" != 0 ] || fail "After giving up, the agent should exit with a failure status."
n=$(curl -s -m 2 "http://127.0.0.1:$port/stats" | jq -r .requests 2>/dev/null)
[ "${n:-99}" -le 12 ] || fail "The agent asked the model $n times before stopping: keep the step limit at 10 or fewer."
