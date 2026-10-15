. "$LAB_LIB"
f=app/deployment.yaml
[ -f "$f" ] || fail "app/deployment.yaml does not exist."
[ "$(yaml_get "$f" 'd.kind')" = "Deployment" ] || fail "Keep the kind as Deployment."
[ "$(yaml_get "$f" 'd.apiVersion')" = "apps/v1" ] || fail "Deployments use apiVersion apps/v1 now; the beta version was removed."
