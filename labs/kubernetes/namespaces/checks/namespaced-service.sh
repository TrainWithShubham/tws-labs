. "$LAB_LIB"

f="app/dev-service.yaml"
[ -f "$f" ] || fail "app/dev-service.yaml does not exist."

kind=$(yaml_get "$f" 'd && d.kind')
[ "$kind" = "Service" ] || fail "The kind should be Service."

api=$(yaml_get "$f" 'd && d.apiVersion')
[ "$api" = "v1" ] || fail "The apiVersion should be v1."

name=$(yaml_get "$f" 'd && d.metadata && d.metadata.name')
[ "$name" = "web-service" ] || fail "Set metadata.name to web-service."

ns=$(yaml_get "$f" 'd && d.metadata && d.metadata.namespace')
[ "$ns" = "development" ] || fail "Set metadata.namespace to development."

selector=$(yaml_get "$f" 'd && d.spec && d.spec.selector && d.spec.selector.app')
[ "$selector" = "web" ] || fail "Set spec.selector.app to web."

has_ports=$(yaml_get "$f" 'Boolean(d && d.spec && Array.isArray(d.spec.ports) && d.spec.ports.length > 0)')
[ "$has_ports" = "true" ] || fail "spec.ports list is missing in app/dev-service.yaml."

has_port=$(yaml_get "$f" 'Boolean(d && d.spec && Array.isArray(d.spec.ports) && d.spec.ports.some(p => p.port == 80))')
[ "$has_port" = "true" ] || fail "Configure a port entry in spec.ports with port: 80."

has_target_port=$(yaml_get "$f" 'Boolean(d && d.spec && Array.isArray(d.spec.ports) && d.spec.ports.some(p => p.port == 80 && p.targetPort !== undefined && p.targetPort !== null && String(p.targetPort).trim() !== ""))')
[ "$has_target_port" = "true" ] || fail "Set targetPort: 80 under spec.ports (targetPort must not be omitted)."

match_target_port=$(yaml_get "$f" 'Boolean(d && d.spec && Array.isArray(d.spec.ports) && d.spec.ports.some(p => p.port == 80 && p.targetPort == 80))')
[ "$match_target_port" = "true" ] || fail "Configure targetPort: 80 under spec.ports."
