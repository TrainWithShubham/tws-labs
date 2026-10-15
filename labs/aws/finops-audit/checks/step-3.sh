. "$LAB_LIB"
same() {
  name="$1"; shift
  f="$LAB_HOME/$name"
  [ -s "$f" ] || { fail "Save your results to $name"; exit 1; }
  got=$(tr -d ' \r",' < "$f" | grep -v '^$' | sort -u)
  want=$(printf '%s\n' "$@" | sort -u)
  [ "$got" = "$want" ] || { fail "$name should list exactly the expected resources"; exit 1; }
}
same rds_instances.txt orders-db analytics-db
same dynamodb_tables.txt orders sessions audit_log
