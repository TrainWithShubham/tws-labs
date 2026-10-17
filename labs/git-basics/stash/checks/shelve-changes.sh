. "$LAB_LIB"
[ -n "$(in_repo proj stash list)" ] || fail "No stashed changes found. Run git stash."
[ -z "$(in_repo proj status --porcelain)" ] || fail "Your working tree still has uncommitted changes. Stash them with git stash."

