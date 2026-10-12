. "$LAB_LIB"
[ -f networking-commands.sh ] || fail "Create networking-commands.sh first."
file_has networking-commands.sh '^docker exec app1 ping -c 3 app2$' || fail 'Add the required Docker command to networking-commands.sh.'
