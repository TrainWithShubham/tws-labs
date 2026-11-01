. "$LAB_LIB"

f="app/ingress.yaml"
[ -f "$f" ] || fail "app/ingress.yaml does not exist yet."
[ "$(yaml_get "$f" "d.kind")" = "Ingress" ] || fail "The kind should be Ingress."
[ "$(yaml_get "$f" "d.apiVersion")" = "networking.k8s.io/v1" ] || fail "Use apiVersion networking.k8s.io/v1 (the older beta versions were removed)."
paths='(((d.spec||{}).rules||[]).flatMap(r=>((r.http||{}).paths||[]).map(p=>Object.assign({host:r.host},p))))'

ok=$(yaml_get "$f" "Boolean($paths.some(p=>p.host==='shop.example.com' && p.path==='/api' && p.pathType==='Prefix' && p.backend && p.backend.service && p.backend.service.name==='api' && p.backend.service.port && (p.backend.service.port.number===8080 || p.backend.service.port.name==='http-api')))")
[ "$ok" = "true" ] || fail "Add path /api (pathType Prefix) under host shop.example.com, sent to Service api on the port that Service exposes."
