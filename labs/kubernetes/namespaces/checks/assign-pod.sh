. "$LAB_LIB"

f="app/dev-pod.yaml"
[ -f "$f" ] || fail "app/dev-pod.yaml does not exist."

kind=$(yaml_get "$f" 'd && d.kind')
[ "$kind" = "Pod" ] || fail "The kind should be Pod."

api=$(yaml_get "$f" 'd && d.apiVersion')
[ "$api" = "v1" ] || fail "The apiVersion should be v1."

name=$(yaml_get "$f" 'd && d.metadata && d.metadata.name')
[ "$name" = "web-backend" ] || fail "metadata.name should be web-backend."

ns=$(yaml_get "$f" 'd && d.metadata && d.metadata.namespace')
[ "$ns" = "development" ] || fail "Set metadata.namespace to development."

label=$(yaml_get "$f" 'd && d.metadata && d.metadata.labels && d.metadata.labels.app')
[ "$label" = "web" ] || fail "Keep metadata.labels.app set to web."

has_c=$(yaml_get "$f" 'Boolean(d && d.spec && Array.isArray(d.spec.containers) && d.spec.containers.some(c => c.name === "nginx" && c.image === "nginx:1.27" && Array.isArray(c.ports) && c.ports.some(p => p.containerPort == 80)))')
[ "$has_c" = "true" ] || fail "Container nginx with image nginx:1.27 and containerPort 80 must be preserved."

