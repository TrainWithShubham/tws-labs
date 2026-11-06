. "$LAB_LIB"

ns_file="app/prod-ns.yaml"
pod_file="app/prod-pod.yaml"

[ -f "$ns_file" ] || fail "app/prod-ns.yaml does not exist."
[ "$(yaml_get "$ns_file" 'd && d.kind')" = "Namespace" ] || fail "app/prod-ns.yaml kind must be Namespace."
[ "$(yaml_get "$ns_file" 'd && d.apiVersion')" = "v1" ] || fail "app/prod-ns.yaml apiVersion must be v1."
[ "$(yaml_get "$ns_file" 'd && d.metadata && d.metadata.name')" = "production" ] || fail "app/prod-ns.yaml metadata.name must be production."

ns_scope=$(yaml_get "$ns_file" 'd && d.metadata && d.metadata.namespace')
[ -z "$ns_scope" ] || [ "$ns_scope" = "null" ] || [ "$ns_scope" = "undefined" ] || fail "Namespace production is cluster-scoped and must not specify metadata.namespace."

[ -f "$pod_file" ] || fail "app/prod-pod.yaml does not exist."
[ "$(yaml_get "$pod_file" 'd && d.kind')" = "Pod" ] || fail "app/prod-pod.yaml kind must be Pod."
[ "$(yaml_get "$pod_file" 'd && d.apiVersion')" = "v1" ] || fail "app/prod-pod.yaml apiVersion must be v1."
[ "$(yaml_get "$pod_file" 'd && d.metadata && d.metadata.name')" = "web-backend" ] || fail "app/prod-pod.yaml metadata.name must be web-backend."
[ "$(yaml_get "$pod_file" 'd && d.metadata && d.metadata.namespace')" = "production" ] || fail "app/prod-pod.yaml metadata.namespace must be production."
[ "$(yaml_get "$pod_file" 'd && d.metadata && d.metadata.labels && d.metadata.labels.app')" = "web" ] || fail "app/prod-pod.yaml metadata.labels.app must be web."

has_c=$(yaml_get "$pod_file" 'Boolean(d && d.spec && Array.isArray(d.spec.containers) && d.spec.containers.some(c => c.name === "nginx" && c.image === "nginx:1.27"))')
[ "$has_c" = "true" ] || fail "app/prod-pod.yaml container nginx must use image nginx:1.27."

has_ports=$(yaml_get "$pod_file" 'Boolean(d && d.spec && Array.isArray(d.spec.containers) && d.spec.containers.some(c => c.name === "nginx" && Array.isArray(c.ports) && c.ports.length > 0))')
[ "$has_ports" = "true" ] || fail "app/prod-pod.yaml container nginx must declare a ports list."

has_port=$(yaml_get "$pod_file" 'Boolean(d && d.spec && Array.isArray(d.spec.containers) && d.spec.containers.some(c => c.name === "nginx" && Array.isArray(c.ports) && c.ports.some(p => p.containerPort == 80)))')
[ "$has_port" = "true" ] || fail "app/prod-pod.yaml container nginx must declare containerPort: 80."
