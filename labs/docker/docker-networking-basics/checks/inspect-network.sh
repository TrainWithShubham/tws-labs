. "$LAB_LIB"
[ -f networking-commands.sh ] || fail "Create networking-commands.sh first."
file_has networking-commands.sh '^docker network inspect app-network$' || fail 'Add the required Docker command to networking-commands.sh.'
