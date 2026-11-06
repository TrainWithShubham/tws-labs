. "$LAB_LIB"

[ -f deploy/hooks/pre-deploy.sh ] || fail "deploy/hooks/pre-deploy.sh is missing."
[ -x deploy/hooks/pre-deploy.sh ] || fail "deploy/hooks/pre-deploy.sh is not executable."
