. "$LAB_LIB"
f=app/deployment.yaml
[ -f "$f" ] || fail "app/deployment.yaml does not exist."
ok=$(yaml_get "$f" 'Boolean(d.spec && d.spec.template && d.spec.template.spec && d.spec.template.spec.containers && d.spec.template.spec.containers[0] && d.spec && d.spec.template && d.spec.template.spec && d.spec.template.spec.containers && d.spec.template.spec.containers[0].env && d.spec && d.spec.template && d.spec.template.spec && d.spec.template.spec.containers && d.spec.template.spec.containers[0].env.some(e => e.name === "DB_PASSWORD" && e.valueFrom && e.valueFrom.secretKeyRef && e.valueFrom.secretKeyRef.name === "db-credentials" && e.valueFrom.secretKeyRef.key === "DB_PASSWORD"))')
[ "$ok" = "true" ] || fail "Add env DB_PASSWORD with valueFrom.secretKeyRef (name db-credentials, key DB_PASSWORD)."
