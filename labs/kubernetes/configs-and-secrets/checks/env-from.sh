. "$LAB_LIB"
f=app/deployment.yaml
[ -f "$f" ] || fail "app/deployment.yaml does not exist."
ok=$(yaml_get "$f" 'Boolean(d.spec && d.spec.template && d.spec.template.spec && d.spec.template.spec.containers && d.spec.template.spec.containers[0] && d.spec && d.spec.template && d.spec.template.spec && d.spec.template.spec.containers && d.spec.template.spec.containers[0].envFrom && d.spec && d.spec.template && d.spec.template.spec && d.spec.template.spec.containers && d.spec.template.spec.containers[0].envFrom.some(e => e.configMapRef && e.configMapRef.name === "app-config"))')
[ "$ok" = "true" ] || fail "Add envFrom with a configMapRef named app-config to the container."
