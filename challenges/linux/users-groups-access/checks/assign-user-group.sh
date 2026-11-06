. "$LAB_LIB"

[ -f access/config/group-membership.conf ] || fail "access/config/group-membership.conf is missing."
grep -Eq "^deploy-agent:engineers$" access/config/group-membership.conf || fail "deploy-agent must be assigned to group engineers in access/config/group-membership.conf."
