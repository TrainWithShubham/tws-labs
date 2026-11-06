. "$LAB_LIB"

svc="app/api-service.yaml"
pod="app/api-pod.yaml"

[ -f "$svc" ] || fail "app/api-service.yaml does not exist."
[ -f "$pod" ] || fail "app/api-pod.yaml does not exist."

[ "$(yaml_get "$svc" 'd && d.kind')" = "Service" ] || fail "app/api-service.yaml kind must be Service."
[ "$(yaml_get "$svc" 'd && d.apiVersion')" = "v1" ] || fail "app/api-service.yaml apiVersion must be v1."
[ "$(yaml_get "$svc" 'd && d.metadata && d.metadata.name')" = "api-service" ] || fail "metadata.name must remain api-service."

ns=$(yaml_get "$svc" 'd && d.metadata && d.metadata.namespace')
[ "$ns" = "development" ] || fail "Set metadata.namespace to development in app/api-service.yaml."

pod_ns=$(yaml_get "$pod" 'd && d.metadata && d.metadata.namespace')
[ "$ns" = "$pod_ns" ] || fail "Service namespace ($ns) does not match Pod namespace ($pod_ns)."

sel=$(yaml_get "$svc" 'd && d.spec && d.spec.selector && d.spec.selector.app')
[ "$sel" = "api-worker" ] || fail "Set spec.selector.app to api-worker in app/api-service.yaml."

pod_lbl=$(yaml_get "$pod" 'd && d.metadata && d.metadata.labels && d.metadata.labels.app')
[ "$sel" = "$pod_lbl" ] || fail "Service selector app ($sel) does not match Pod label ($pod_lbl)."

has_port=$(yaml_get "$svc" 'Boolean(d && d.spec && Array.isArray(d.spec.ports) && d.spec.ports.some(p => p.port == 8080 && (p.targetPort == 8080 || p.targetPort === undefined)))')
[ "$has_port" = "true" ] || fail "Preserve spec.ports with port: 8080 and targetPort: 8080."

