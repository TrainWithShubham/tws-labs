. "$LAB_LIB"

f="batch/job.yaml"
[ -f "$f" ] || fail "batch/job.yaml does not exist."
[ "$(yaml_get "$f" 'd.kind')" = "Job" ] || fail "The kind should still be Job."
for want in completions:6 parallelism:2 backoffLimit:3; do
  k=${want%%:*}; v=${want#*:}
  [ "$(yaml_get "$f" "typeof d.spec[\"$k\"] === 'number' && d.spec[\"$k\"] === $v")" = "true" ] ||
    fail "Under spec, set $k to the number $v (a plain number, not text)."
done
