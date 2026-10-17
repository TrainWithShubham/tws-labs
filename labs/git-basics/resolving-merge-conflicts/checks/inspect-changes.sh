. "$LAB_LIB"
[ -s "$LAB_HOME/changes.diff" ] || fail "Save the branch comparison to changes.diff in your home directory."
in_repo proj diff --no-ext-diff --no-color main feature -- app.conf | cmp -s - "$LAB_HOME/changes.diff" || fail "Compare main against feature for app.conf and save the complete patch."
ran_re '(^|[;&|(][[:space:]]*)git([[:space:]]+-C[[:space:]]+("[^"]+"|[^[:space:];&|]+))?[[:space:]]+diff([[:space:]]|$)' || fail "Use git diff to generate the comparison, rather than typing a patch yourself."
