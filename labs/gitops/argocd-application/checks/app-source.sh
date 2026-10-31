. "$LAB_LIB"
f=guestbook-app.yaml
[ -f "$f" ] || fail "guestbook-app.yaml does not exist yet."
[ -n "$(yaml_get "$f" 'd && typeof d === "object" ? 1 : ""')" ] || fail "guestbook-app.yaml is not valid YAML (or is empty)."
[ "$(yaml_get "$f" 'd.apiVersion')" = "argoproj.io/v1alpha1" ] || fail "apiVersion should be argoproj.io/v1alpha1."
[ "$(yaml_get "$f" 'd.kind')" = "Application" ] || fail "kind should be Application."
[ "$(yaml_get "$f" 'd.metadata && d.metadata.name')" = "guestbook" ] || fail "metadata.name should be guestbook."
[ "$(yaml_get "$f" 'd.metadata && d.metadata.namespace')" = "argocd" ] || fail "metadata.namespace should be argocd, where Argo CD looks for Applications."
[ "$(yaml_get "$f" 'd.spec && d.spec.project')" = "default" ] || fail "spec.project should be default."
yaml_get "$f" 'typeof (d.spec && d.spec.source && d.spec.source.repoURL) === "string" && /^https:\/\/[^ ]+$/.test(d.spec.source.repoURL)' | grep -qx true ||
  fail "spec.source.repoURL should be the https URL of the Git repository."
[ "$(yaml_get "$f" 'd.spec && d.spec.source && d.spec.source.path')" = "guestbook" ] || fail "spec.source.path should be guestbook (the folder in the repo)."
yaml_get "$f" 'typeof (d.spec && d.spec.source && d.spec.source.targetRevision) === "string" && d.spec.source.targetRevision.length > 0' | grep -qx true ||
  fail "spec.source.targetRevision is missing (a branch, tag or HEAD)."
