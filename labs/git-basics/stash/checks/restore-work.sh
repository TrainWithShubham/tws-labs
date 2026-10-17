. "$LAB_LIB"
[ "$(in_repo proj branch --show-current)" = "feature" ] || fail "You are not on the feature branch. Run git switch feature."
[ -n "$(in_repo proj status --porcelain)" ] || fail "No uncommitted changes in your working tree. Run git stash pop."
in_repo proj diff | grep -q "uncommitted" || fail "app.py does not contain your restored uncommitted changes."
[ -z "$(in_repo proj stash list)" ] || fail "Stash list is not empty. Did you use git stash pop?"

