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
S=read_config.py
[ -f "$S" ] || fail "$S does not exist yet."
run() { out=$(cd "$d" && _timeout 5 python3 "$LAB_HOME/$S" "$@" 2>"$d/err" </dev/null); rc=$?; err=$(cat "$d/err"); }
ref() { python3 -c 'import json, sys
c = json.load(open(sys.argv[1]))
print(json.dumps({**c["defaults"], **c.get("environments", {}).get(sys.argv[2], {})}, indent=int(sys.argv[3]), sort_keys=True))' "$@"; }
nice_fail() { run "$@"; [ "$rc" -ne 0 ] || fail "$1 is not valid but the script exited 0: report the problem and exit non-zero."; case "$err" in *Traceback*) fail "A bad config produced a Python traceback: catch the problem and print a clear message instead." ;; esac; }

run "$d/a.json"; [ "$out" = "billing: 5 default settings" ] || fail "Run on a config with app billing and 5 defaults, it should print exactly: billing: 5 default settings"
run "$d/b.json"; [ "$out" = "search: 2 default settings" ] || fail "Run on another config it printed the wrong line: read the app name and count the defaults from the file you are given."
