. "$LAB_LIB"

f="app/service.yaml"
[ -f "$f" ] || fail "app/service.yaml does not exist."

dep="app/deployment.yaml"
[ -f "$dep" ] || fail "app/deployment.yaml does not exist."

kind=$(yaml_get "$f" 'd.kind')
[ "$kind" = "Service" ] || fail "The kind should be Service."

name=$(yaml_get "$f" 'd.metadata && d.metadata.name')
[ "$name" = "nginx-service" ] || fail "Name the Service nginx-service in metadata.name."

dep_label=$(yaml_get "$dep" 'd.spec && d.spec.template && d.spec.template.metadata && d.spec.template.metadata.labels && d.spec.template.metadata.labels.app')
[ -n "$dep_label" ] && [ "$dep_label" != "null" ] || fail "Deployment Pod template label app is missing in app/deployment.yaml."

svc_selector=$(yaml_get "$f" 'd.spec && d.spec.selector && d.spec.selector.app')
[ -n "$svc_selector" ] && [ "$svc_selector" != "null" ] || fail "Add selector with app under spec in app/service.yaml."

[ "$svc_selector" = "$dep_label" ] || fail "Service selector app ($svc_selector) does not match Deployment Pod template label ($dep_label)."

