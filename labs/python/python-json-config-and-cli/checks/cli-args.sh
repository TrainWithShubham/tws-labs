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
S=config_cli.py
[ -f "$S" ] || fail "$S does not exist yet."
run() { out=$(cd "$d" && _timeout 5 python3 "$LAB_HOME/$S" "$@" 2>"$d/err" </dev/null); rc=$?; err=$(cat "$d/err"); }
ref() { python3 -c 'import json, sys
c = json.load(open(sys.argv[1]))
print(json.dumps({**c["defaults"], **c.get("environments", {}).get(sys.argv[2], {})}, indent=int(sys.argv[3]), sort_keys=True))' "$@"; }
nice_fail() { run "$@"; [ "$rc" -ne 0 ] || fail "$1 is not valid but the script exited 0: report the problem and exit non-zero."; case "$err" in *Traceback*) fail "A bad config produced a Python traceback: catch the problem and print a clear message instead." ;; esac; }

run "$d/a.json"; [ "$rc" = 0 ] && [ "$out" = "file=$d/a.json env=dev" ] || fail "With only a path it should print file=<path> env=dev."
run "$d/b.json" --env prod; [ "$out" = "file=$d/b.json env=prod" ] || fail "With --env prod after the path it should print file=<path> env=prod."
run --env staging "$d/b.json"; [ "$out" = "file=$d/b.json env=staging" ] || fail "--env should work before the path too."
run --help; [ "$rc" = 0 ] || fail "--help should print usage and exit 0."
case "$out" in *--env*) ;; *) fail "--help should mention the --env option." ;; esac
run "$d/a.json" --env test; [ "$rc" -ne 0 ] || fail "An environment that is not dev, staging or prod should be refused with a non-zero exit."
case "$err" in *Traceback*) fail "An unknown environment produced a traceback." ;; esac
run; [ "$rc" -ne 0 ] || fail "Without a config path the script should fail with usage."
