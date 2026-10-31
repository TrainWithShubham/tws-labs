. "$LAB_LIB"

f="batch/cleanup-job.yaml"
[ -f "$f" ] || fail "batch/cleanup-job.yaml does not exist."
[ "$(yaml_get "$f" 'd.kind')" = "Job" ] || fail "The kind should stay Job."
[ "$(yaml_get "$f" 'd.metadata && d.metadata.name')" = "cleanup" ] || fail "Keep the Job name cleanup."
pod='d.spec && d.spec.template && d.spec.template.spec'
[ "$(yaml_get "$f" "Boolean($pod && Array.isArray($pod.containers) && $pod.containers.some(c => c && c.image))")" = "true" ] || fail "The Pod template still needs its container."
rp=$(yaml_get "$f" "$pod && $pod.restartPolicy")
case "$rp" in
  OnFailure|Never) ;;
  Always) fail "restartPolicy: Always would restart finished Pods forever, so the API rejects it for a Job." ;;
  *) fail "Set spec.template.spec.restartPolicy to OnFailure or Never (the exact spelling matters)." ;;
esac
