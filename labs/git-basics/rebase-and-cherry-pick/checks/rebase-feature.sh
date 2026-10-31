. "$LAB_LIB"
G="$LAB_HOME/proj"
[ -d "$G/.git" ] || fail "The proj repository is missing."
[ ! -d "$G/.git/rebase-merge" ] && [ ! -d "$G/.git/rebase-apply" ] || fail "A rebase is still in progress: finish it with git rebase --continue."
in_repo proj rev-parse --verify -q feature >/dev/null || fail "The feature branch is missing."
tip=$(in_repo proj log feature -1 --format=%H --grep='^Add changelog$') || true
[ -n "$tip" ] || fail "feature does not contain main's newest commit (Add changelog) yet."
[ "$(in_repo proj rev-list --merges --count feature)" = 0 ] || fail "feature has a merge commit. Rebase instead of merging."
first=$(in_repo proj log feature -1 --format=%H --grep='^Add login form$')
[ -n "$first" ] || fail "The commit Add login form is missing from feature."
in_repo proj log feature -1 --format=%H --grep='^Add login validation$' | grep -q . || fail "The commit Add login validation is missing from feature."
[ "$(in_repo proj rev-parse "$first^")" = "$tip" ] || fail "feature's own commits should sit directly on top of main's Add changelog commit."
