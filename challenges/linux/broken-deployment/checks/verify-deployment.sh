. "$LAB_LIB"

[ ! -f deploy/.deploy.lock ] || fail "deploy/.deploy.lock still exists. Remove the lock file."
[ -f deploy/reports/deploy-verification.status ] || fail "deploy/reports/deploy-verification.status not found. Run ./verify-deployment."

grep -Fxq "DEPLOYMENT_STATE=VERIFIED" deploy/reports/deploy-verification.status || fail "Verification status is missing DEPLOYMENT_STATE=VERIFIED."
grep -Fxq "COMPONENTS=APP_CLI:APP_ENV:PRE_DEPLOY_HOOK" deploy/reports/deploy-verification.status || fail "Verification status is missing valid COMPONENTS line."
grep -Fxq "TARGET_REVISION=v2" deploy/reports/deploy-verification.status || fail "Verification status is missing TARGET_REVISION=v2."
grep -Fxq "VERIFIED_BY=local_preflight" deploy/reports/deploy-verification.status || fail "Verification status is missing VERIFIED_BY=local_preflight."

# Verify underlying state remains valid
[ -L deploy/bin/app-cli ] || fail "deploy/bin/app-cli is not a symlink."
[ "$(readlink -f deploy/bin/app-cli 2>/dev/null)" = "$(readlink -f deploy/bin/app-cli-v2 2>/dev/null)" ] || fail "deploy/bin/app-cli does not resolve to app-cli-v2."
[ -x deploy/hooks/pre-deploy.sh ] || fail "deploy/hooks/pre-deploy.sh is not executable."
