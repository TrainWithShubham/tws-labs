. "$LAB_LIB"
d=$(mktemp -d) && trap 'rm -rf "$d"' EXIT
mk() { mkdir -p "$1/logs"; local i lv sv m; for i in $(seq 1 30); do case $((i % 6)) in 0) lv=ERROR ;; 1|3) lv=WARN ;; *) lv=INFO ;; esac; case $((i % 3)) in 0) sv=billing ;; 1) sv=auth ;; *) sv=search ;; esac; if [ "$lv" = INFO ] && [ $((i % 5)) = 0 ]; then m="recovered from ERROR state"; else m="request handled"; fi; printf '2026-10-02 10:%02d:00 %s %s: %s\n' "$i" "$lv" "$sv" "$m"; done > "$1/logs/app.log"; }
mk "$d"
[ -f filter_logs.py ] || fail "filter_logs.py does not exist yet."
for lv in WARN ERROR; do
  want=$(awk -v l="$lv" '$3 == l' "$d/logs/app.log")
  got=$(cd "$d" && _timeout 3 python3 "$LAB_HOME/filter_logs.py" "$lv" 2>&1)
  [ "$got" = "$want" ] || fail "Run as  python3 filter_logs.py $lv  the script did not print exactly the $lv lines, in order."
done
