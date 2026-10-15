. "$LAB_LIB"

[ -f var/log/app-error.log ] || exit 0

size=$(stat -c %s var/log/app-error.log 2>/dev/null || stat -f %z var/log/app-error.log 2>/dev/null || echo 0)
if [ "$size" -gt 1024 ]; then
  fail "var/log/app-error.log is still too large ($size bytes). Truncate it to 0 bytes."
fi
