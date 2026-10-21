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
[ -f tool.py ] || fail "tool.py does not exist yet."
install -d "$d/x"
printf 'a1\na2\na3\n' > "$d/x/a.txt"
printf 'b1\nb2\nb3\nb4\nb5\n' > "$d/x/b.log"
for f in a.txt b.log; do
  want=$(wc -l < "$d/x/$f" | tr -d ' ')
  got=$(cd "$d/x" && _timeout 3 python3 "$OLDPWD/tool.py" "$f" 2>&1 | tr -d ' ')
  [ "$got" = "$want" ] || fail "python3 tool.py $f printed '${got:-nothing}'. It should print how many lines the file has."
done
