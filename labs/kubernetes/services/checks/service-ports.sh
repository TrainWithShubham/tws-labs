. "$LAB_LIB"

f="app/service.yaml"
[ -f "$f" ] || fail "app/service.yaml does not exist."

kind=$(yaml_get "$f" 'd.kind')
[ "$kind" = "Service" ] || fail "The kind should be Service."

has_ports=$(yaml_get "$f" 'Boolean(d.spec && Array.isArray(d.spec.ports) && d.spec.ports.length > 0)')
[ "$has_ports" = "true" ] || fail "spec.ports list is missing in app/service.yaml."

match=$(yaml_get "$f" 'Boolean(d.spec && d.spec.ports && d.spec.ports.some(p => (p.port == 80) && (p.targetPort == 80)))')
[ "$match" = "true" ] || fail "Configure a port entry in spec.ports with port: 80 and targetPort: 80."

proto=$(yaml_get "$f" 'd.spec && d.spec.ports && (d.spec.ports.find(p => (p.port == 80) && (p.targetPort == 80)).protocol || "TCP")')
[ "$proto" = "TCP" ] || fail "Set protocol: TCP under spec.ports (or omit it for default TCP)."
