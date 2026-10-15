. "$LAB_LIB"
f=shop/.github/workflows/ci.yml
ex=$(yaml_get "$f" 'd.jobs.test.strategy.matrix')
# an exclude entry names at least one of os/node, and every one it names is a real value in the matrix
echo "$ex" | jq -e '. as $m | [($m.exclude // [])[] | . as $e | select(($e.os // $e.node) != null) | select((($e.os // null) == null or ($m.os | index($e.os))) and (($e.node // null) == null or ($m.node | map(tostring) | index($e.node | tostring))))] | length >= 1' >/dev/null 2>&1 \
  || fail "No exclude entry skips a real node + os combination yet."
