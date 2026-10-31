. "$LAB_LIB"
d=$(mktemp -d) && trap 'rm -rf "$d"' EXIT
cat > "$d/a.json" <<'EOF'
{"app": "billing", "defaults": {"port": 9000, "debug": false, "workers": 3, "tags": ["a", "b"], "db": {"host": "db1", "pool": 5}},
 "environments": {"dev": {"debug": true, "workers": 1}, "staging": {"port": 9100}, "prod": {"workers": 12, "db": {"host": "db-prod"}}}}
EOF
cat > "$d/b.json" <<'EOF'
{"app": "search", "defaults": {"zeta": 1, "alpha": 2}}
EOF
printf '{"defaults": {"x": 1}}\n' > "$d/no-app.json"
printf '{"app": "x"}\n' > "$d/no-defaults.json"
printf '{}\n' > "$d/empty.json"
printf '{"app": "x", "defaults": ' > "$d/broken.json"
S=build_config.py
[ -f "$S" ] || fail "$S does not exist yet."
run() { out=$(cd "$d" && _timeout 5 python3 "$LAB_HOME/$S" "$@" 2>"$d/err" </dev/null); rc=$?; err=$(cat "$d/err"); }
ref() { python3 -c 'import json, sys
c = json.load(open(sys.argv[1]))
print(json.dumps({**c["defaults"], **c.get("environments", {}).get(sys.argv[2], {})}, indent=int(sys.argv[3]), sort_keys=True))' "$@"; }
nice_fail() { run "$@"; [ "$rc" -ne 0 ] || fail "$1 is not valid but the script exited 0: report the problem and exit non-zero."; case "$err" in *Traceback*) fail "A bad config produced a Python traceback: catch the problem and print a clear message instead." ;; esac; }

for f in a b; do
  for e in dev prod; do
    rm -f "$d/resolved.json"
    run "$d/$f.json" --env "$e"
    [ "$rc" = 0 ] || fail "$f.json with --env $e should exit 0."
    [ -f "$d/resolved.json" ] || fail "The script should write resolved.json in the current directory."
    got=$(cat "$d/resolved.json"); ok=0
    for n in 2 4; do [ "$got" = "$(ref "$d/$f.json" $e $n)" ] && ok=1; done
    [ "$ok" = 1 ] || fail "resolved.json should hold the merged settings, pretty-printed with sorted keys."
  done
done
for bad in no-app no-defaults broken; do
  rm -f "$d/resolved.json"
  nice_fail "$d/$bad.json"
  [ ! -e "$d/resolved.json" ] || fail "A bad config must not leave a resolved.json behind: validate before you write."
done
