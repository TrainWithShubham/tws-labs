. "$LAB_LIB"

[ -f deploy/scripts/backup.sh ] || fail "deploy/scripts/backup.sh is missing."
[ -x deploy/scripts/backup.sh ] || fail "deploy/scripts/backup.sh is not executable."
