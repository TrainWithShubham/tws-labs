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
S=validate_config.py
[ -f "$S" ] || fail "$S does not exist yet."
run() { out=$(cd "$d" && _timeout 5 python3 "$LAB_HOME/$S" "$@" 2>"$d/err" </dev/null); rc=$?; err=$(cat "$d/err"); }
ref() { python3 -c 'import json, sys
c = json.load(open(sys.argv[1]))
print(json.dumps({**c["defaults"], **c.get("environments", {}).get(sys.argv[2], {})}, indent=int(sys.argv[3]), sort_keys=True))' "$@"; }
nice_fail() { run "$@"; [ "$rc" -ne 0 ] || fail "$1 is not valid but the script exited 0: report the problem and exit non-zero."; case "$err" in *Traceback*) fail "A bad config produced a Python traceback: catch the problem and print a clear message instead." ;; esac; }

for f in a b; do run "$d/$f.json"; [ "$rc" = 0 ] && [ "$out" = "ok" ] || fail "A complete config should print ok and exit 0."; done
nice_fail "$d/no-app.json"
case "$out$err" in *app*) ;; *) fail "The message for a config without app should name the missing key." ;; esac
[ "$out" != "ok" ] || fail "A config without app must not print ok."
nice_fail "$d/no-defaults.json"
case "$out$err" in *defaults*) ;; *) fail "The message for a config without defaults should name the missing key." ;; esac
nice_fail "$d/empty.json"
nice_fail "$d/broken.json"
nice_fail "$d/does-not-exist.json"
