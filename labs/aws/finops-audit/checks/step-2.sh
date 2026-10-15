. "$LAB_LIB"
same() {
  name="$1"; shift
  f="$LAB_HOME/$name"
  [ -s "$f" ] || { fail "Save your results to $name"; exit 1; }
  got=$(tr -d ' \r",' < "$f" | grep -v '^$' | sort -u)
  want=$(printf '%s\n' "$@" | sort -u)
  [ "$got" = "$want" ] || { fail "$name should list exactly the expected resources"; exit 1; }
}
same unattached_ebs.txt vol-0a1b2c3d4e5f60001 vol-0a1b2c3d4e5f60003
same s3_buckets.txt finops-demo-logs finops-demo-backups finops-demo-assets
