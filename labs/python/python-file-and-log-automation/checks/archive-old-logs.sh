. "$LAB_LIB"
d=$(mktemp -d) && trap 'rm -rf "$d"' EXIT
[ -f archive_logs.py ] || fail "archive_logs.py does not exist yet."
install -d "$d/logs"
for i in $(seq 1 90); do echo "event $i padding padding padding"; done > "$d/logs/big.log"
echo "tiny" > "$d/logs/small.log"
want=$(md5sum < "$d/logs/big.log")
(cd "$d" && _timeout 3 python3 "$LAB_HOME/archive_logs.py" >/dev/null 2>&1) || fail "archive_logs.py failed or took too long: run it yourself and read the error."
[ -f "$d/logs/archive/big.log.gz" ] || fail "The big log was not compressed into logs/archive/ as <name>.gz."
[ ! -e "$d/logs/big.log" ] || fail "The big log is still in logs/: it should be moved into the archive, not copied."
[ "$(gzip -dc "$d/logs/archive/big.log.gz" 2>/dev/null | md5sum)" = "$want" ] || fail "The archived file does not decompress to the original log."
[ -f "$d/logs/small.log" ] || fail "A small log was archived too: only files over the size limit should move."
[ ! -e "$d/logs/archive/small.log.gz" ] || fail "A small log was archived too: only files over the size limit should move."
