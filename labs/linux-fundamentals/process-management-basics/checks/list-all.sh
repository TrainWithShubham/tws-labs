. "$LAB_LIB"
ran_re '(^|[;&|[:space:]])ps[[:space:]]+-?[a-zA-Z]*[ae]' ||
  fail "Run ps -a to list terminal processes."
