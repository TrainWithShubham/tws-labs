. "$LAB_LIB"
ran_re '(^|[;&|[:space:]])ps[[:space:]]+-?[a-zA-Z]*u' ||
  fail "Run ps -u to list your user's processes."
