. "$LAB_LIB"
[ "$(cat workspace/hello.txt 2>/dev/null)" = "hello linux" ] || fail "workspace/hello.txt should contain exactly: hello linux"
