. "$LAB_LIB"
d=$(mktemp -d) && trap 'rm -rf "$d"' EXIT
mk() { mkdir -p "$1/logs"; local i lv sv m; for i in $(seq 1 30); do case $((i % 6)) in 0) lv=ERROR ;; 1|3) lv=WARN ;; *) lv=INFO ;; esac; case $((i % 3)) in 0) sv=billing ;; 1) sv=auth ;; *) sv=search ;; esac; if [ "$lv" = INFO ] && [ $((i % 5)) = 0 ]; then m="recovered from ERROR state"; else m="request handled"; fi; printf '2026-10-02 10:%02d:00 %s %s: %s\n' "$i" "$lv" "$sv" "$m"; done > "$1/logs/app.log"; }
mk "$d"
[ -f count_errors.py ] || fail "count_errors.py does not exist yet."
want=$(awk '$3 == "ERROR"' "$d/logs/app.log" | wc -l | tr -d ' ')
got=$(cd "$d" && _timeout 3 python3 "$LAB_HOME/count_errors.py" 2>&1 | tr -d ' \r')
[ "$got" = "$want" ] || fail "On a log it has not seen before, the script printed '${got:-nothing}'. It should print how many lines have the level ERROR."
