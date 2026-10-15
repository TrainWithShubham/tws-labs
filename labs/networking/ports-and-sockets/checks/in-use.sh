. "$LAB_LIB"
listening "$(cat port.txt)" || fail "Your first listener stopped - start it again, then retry the second server."
ran_re '(2>|&>)[[:space:]]*error\.txt' || fail "Run the second server with its error output sent to error.txt (2> error.txt), so the system itself explains the refusal."
file_has error.txt 'Address already in use' || fail "error.txt does not hold the refusal. Run the openssl command and keep its error output."
