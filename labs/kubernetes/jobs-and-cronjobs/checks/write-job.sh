. "$LAB_LIB"

f="batch/job.yaml"
[ -f "$f" ] || fail "batch/job.yaml does not exist yet."
[ "$(yaml_get "$f" 'd.apiVersion')" = "batch/v1" ] || fail "A Job uses apiVersion batch/v1."
[ "$(yaml_get "$f" 'd.kind')" = "Job" ] || fail "The kind should be Job."
[ "$(yaml_get "$f" 'd.metadata && d.metadata.name')" = "report" ] || fail "Name the Job report in metadata.name."
pod='d.spec && d.spec.template && d.spec.template.spec'
[ "$(yaml_get "$f" "Boolean($pod && Array.isArray($pod.containers) && $pod.containers.some(c => c && c.name && c.image))")" = "true" ] || fail "Under spec.template.spec add a containers list with a named container and an image."
rp=$(yaml_get "$f" "$pod && $pod.restartPolicy")
case "$rp" in
  OnFailure|Never) ;;
  *) fail "A Job's Pod template needs spec.template.spec.restartPolicy set to OnFailure or Never." ;;
esac
