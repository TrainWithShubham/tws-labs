. "$LAB_LIB"
f=shop/.github/workflows/ci.yml
[ -f "$f" ] || fail "shop/.github/workflows/ci.yml does not exist yet."
n=$(yaml_get "$f" 'd && d.name')
[ -n "$n" ] || fail "ci.yml is not valid YAML yet (check the indentation and the colons)."
{ [ "$n" != undefined ] && [ "$n" != null ]; } || fail "ci.yml has no name yet: write a name after name: (for example CI)."
