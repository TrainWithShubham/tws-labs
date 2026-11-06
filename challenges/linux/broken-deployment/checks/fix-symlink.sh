. "$LAB_LIB"

[ -e deploy/bin/app-cli ] || [ -L deploy/bin/app-cli ] || fail "deploy/bin/app-cli is missing."
[ -L deploy/bin/app-cli ] || fail "deploy/bin/app-cli is not a symlink."
[ -e deploy/bin/app-cli ] || fail "deploy/bin/app-cli is a broken symlink."

resolved=$(readlink -f deploy/bin/app-cli 2>/dev/null)
expected=$(readlink -f deploy/bin/app-cli-v2 2>/dev/null)
[ -n "$expected" ] && [ "$resolved" = "$expected" ] || fail "deploy/bin/app-cli does not resolve to app-cli-v2."
