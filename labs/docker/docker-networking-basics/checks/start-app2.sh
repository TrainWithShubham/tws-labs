. "$LAB_LIB"
[ -f networking-commands.sh ] || fail "Create networking-commands.sh first."
file_has networking-commands.sh '^docker run -d --name app2 --network app-network alpine sleep 300$' || fail 'Add the required Docker command to networking-commands.sh.'
