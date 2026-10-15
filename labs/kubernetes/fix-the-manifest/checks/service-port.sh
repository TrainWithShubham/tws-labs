. "$LAB_LIB"
d=app/deployment.yaml
s=app/service.yaml
[ -f "$d" ] && [ -f "$s" ] || fail "app/deployment.yaml and app/service.yaml must both exist."
cport=$(yaml_get "$d" 'd.spec && d.spec.template && d.spec.template.spec && d.spec.template.spec.containers && d.spec.template.spec.containers[0] && d.spec.template.spec.containers[0].ports && d.spec.template.spec.containers[0].ports[0].containerPort')
[ -n "$cport" ] && [ "$cport" != "undefined" ] || fail "The container no longer declares a containerPort; keep it as it was."
[ "$(yaml_get "$s" 'd.spec.ports[0].port')" = "80" ] || fail "Leave the Service's own port at 80."
[ "$(yaml_get "$s" 'd.spec.ports[0].targetPort')" = "$cport" ] || fail "targetPort must be the container's port ($cport)."
