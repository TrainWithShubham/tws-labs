. "$LAB_LIB"
listening "$(cat port3.txt)" && fail "Something listens on the port in port3.txt - stop it, nobody should be there."
ran_re '(2>|&>)[[:space:]]*refused\.txt' || fail "Make the connection yourself and send curl's error output to refused.txt (2> refused.txt)."
grep -qi 'refused' refused.txt 2>/dev/null || fail "refused.txt does not show a refused connection. Run curl with -v as shown and keep its output."
