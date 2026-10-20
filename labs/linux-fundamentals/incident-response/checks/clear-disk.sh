. "$LAB_LIB"

[ -f var/log/app-error.log ] || fail "var/log/app-error.log is gone. Truncate it to 0 bytes instead of deleting it, so the service can keep writing to it."

size=$(stat -c %s var/log/app-error.log 2>/dev/null || echo 0)
if [ "$size" -gt 1024 ]; then
  fail "var/log/app-error.log is still too large ($size bytes). Truncate it to 0 bytes."
fi
