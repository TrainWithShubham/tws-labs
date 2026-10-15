. "$LAB_LIB"
# the readme is docs/readme.txt: either name that path, or cd into docs first and then cat readme.txt
ran_re '^cat +(\./)?docs/readme\.txt' ||
  { ran_re '^cd +(\./)?docs/?$' && ran_re '^cat +(\./)?readme\.txt'; } ||
  fail "Use cat on docs/readme.txt (give the path, or cd into docs first)."
