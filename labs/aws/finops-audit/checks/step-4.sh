. "$LAB_LIB"
same() {
  name="$1"; shift
  f="$LAB_HOME/$name"
  [ -s "$f" ] || { fail "Save your results to $name"; exit 1; }
  got=$(tr -d ' \r",' < "$f" | grep -v '^$' | sort -u)
  want=$(printf '%s\n' "$@" | sort -u)
  [ "$got" = "$want" ] || { fail "$name should list exactly the expected resources"; exit 1; }
}
same idle_eips.txt eipalloc-0a1b2c3d40001 eipalloc-0a1b2c3d40002
same nat_gateways.txt nat-0a1b2c3d4e5f60001
