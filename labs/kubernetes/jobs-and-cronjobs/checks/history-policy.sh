. "$LAB_LIB"

f="batch/cronjob.yaml"
[ -f "$f" ] || fail "batch/cronjob.yaml does not exist."
[ "$(yaml_get "$f" 'd.kind')" = "CronJob" ] || fail "The kind should still be CronJob."
[ "$(yaml_get "$f" 'd.spec && d.spec.concurrencyPolicy')" = "Forbid" ] || fail "Set spec.concurrencyPolicy to Forbid (directly under spec; the value is case-sensitive)."
for want in successfulJobsHistoryLimit:2 failedJobsHistoryLimit:1; do
  k=${want%%:*}; v=${want#*:}
  [ "$(yaml_get "$f" "typeof d.spec[\"$k\"] === 'number' && d.spec[\"$k\"] === $v")" = "true" ] ||
    fail "Directly under spec, set $k to the number $v."
done
