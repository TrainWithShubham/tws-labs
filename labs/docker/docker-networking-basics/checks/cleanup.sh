. "$LAB_LIB"
[ -f networking-commands.sh ] || fail "Create networking-commands.sh first."
file_has networking-commands.sh '^docker rm -f app1 app2$' || fail "Add the container cleanup command."
file_has networking-commands.sh '^docker network rm app-network$' || fail "Add the network cleanup command."
