. "$LAB_LIB"
[ "$(in_repo proj branch --show-current)" = "main" ] || fail "You are not on the main branch. Switch with git switch main."
[ -f "$LAB_HOME/proj/hotfix.txt" ] || fail "hotfix.txt does not exist."
[ -z "$(in_repo proj status --porcelain)" ] || fail "Your working tree has uncommitted changes. Commit your hotfix."
in_repo proj log -1 --pretty=%s | grep -qi "hotfix" || fail "Latest commit on main does not mention hotfix."

