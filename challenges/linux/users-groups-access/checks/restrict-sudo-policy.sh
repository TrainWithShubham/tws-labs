. "$LAB_LIB"

[ -f access/sudoers.d/deploy-agent ] || fail "access/sudoers.d/deploy-agent is missing."
grep -Eq "^deploy-agent[[:space:]]+ALL=\(ALL\)[[:space:]]+NOPASSWD:[[:space:]]*/usr/bin/systemctl restart app$" access/sudoers.d/deploy-agent || fail "deploy-agent sudo rule must permit only /usr/bin/systemctl restart app."
