. "$LAB_LIB"
G="$LAB_HOME/proj"
pid() { git -C "$G" diff-tree -p --root "$1" | git patch-id --stable | cut -d' ' -f1; }
orig=$(in_repo proj log hotfix -1 --format=%H --grep='^Fix crash on empty cart$')
[ -n "$orig" ] || fail "The hotfix branch no longer has the Fix crash on empty cart commit."
tip=$(in_repo proj rev-parse release)
[ "$(in_repo proj log release -1 --format=%s)" = "Fix crash on empty cart" ] || fail "release's newest commit should be Fix crash on empty cart."
[ "$tip" != "$orig" ] || fail "release should get a copy of the commit, not be the hotfix branch itself."
[ "$(pid "$tip")" = "$(pid "$orig")" ] || fail "The copied commit does not change the same lines as the original."
[ "$(in_repo proj log release~1 -1 --format=%s)" = "Prepare release 1.0" ] || fail "release should keep its own history and gain only that one commit."
in_repo proj cat-file -e release:banner.txt 2>/dev/null && fail "The banner commit came along. Pick only the cart fix."
in_repo proj cat-file -e release:debug.txt 2>/dev/null && fail "The debug commit came along. Pick only the cart fix."
[ -z "$(in_repo proj status --porcelain)" ] || fail "Your working tree is not clean. Finish or abort the cherry-pick."
