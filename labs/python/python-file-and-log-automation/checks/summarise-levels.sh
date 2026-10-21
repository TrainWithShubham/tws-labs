. "$LAB_LIB"
d=$(mktemp -d) && trap 'rm -rf "$d"' EXIT
mk() { mkdir -p "$1/logs"; local i lv sv m; for i in $(seq 1 30); do case $((i % 6)) in 0) lv=ERROR ;; 1|3) lv=WARN ;; *) lv=INFO ;; esac; case $((i % 3)) in 0) sv=billing ;; 1) sv=auth ;; *) sv=search ;; esac; if [ "$lv" = INFO ] && [ $((i % 5)) = 0 ]; then m="recovered from ERROR state"; else m="request handled"; fi; printf '2026-10-02 10:%02d:00 %s %s: %s\n' "$i" "$lv" "$sv" "$m"; done > "$1/logs/app.log"; }
mk "$d"
[ -f summarise.py ] || fail "summarise.py does not exist yet."
(cd "$d" && _timeout 3 python3 "$LAB_HOME/summarise.py" >/dev/null 2>&1) || fail "summarise.py failed or took too long: run it yourself and read the error."
[ -f "$d/report.json" ] || fail "Running the script did not create report.json in the current directory."
want=$(awk '{ n[$3]++ } END { printf "{\"ERROR\":%d,\"INFO\":%d,\"WARN\":%d}", n["ERROR"], n["INFO"], n["WARN"] }' "$d/logs/app.log")
got=$(jq -S -c . "$d/report.json" 2>/dev/null) || fail "report.json is not valid JSON."
[ "$got" = "$want" ] || fail "report.json does not match the log: it should count the lines of each level."
