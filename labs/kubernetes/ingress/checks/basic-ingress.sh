. "$LAB_LIB"

f="app/ingress.yaml"
[ -f "$f" ] || fail "app/ingress.yaml does not exist yet."
[ "$(yaml_get "$f" "d.kind")" = "Ingress" ] || fail "The kind should be Ingress."
[ "$(yaml_get "$f" "d.apiVersion")" = "networking.k8s.io/v1" ] || fail "Use apiVersion networking.k8s.io/v1 (the older beta versions were removed)."
paths='(((d.spec||{}).rules||[]).flatMap(r=>((r.http||{}).paths||[]).map(p=>Object.assign({host:r.host},p))))'

[ "$(yaml_get "$f" 'd.metadata && d.metadata.name')" = "shop" ] || fail "Name the Ingress shop in metadata.name."
[ "$(yaml_get "$f" 'd.spec && d.spec.ingressClassName')" = "public" ] || fail "Set spec.ingressClassName to public (it chooses the controller)."
ok=$(yaml_get "$f" "Boolean($paths.some(p=>p.host==='shop.example.com' && p.path==='/' && p.pathType==='Prefix' && p.backend && p.backend.service && p.backend.service.name==='web' && p.backend.service.port && (p.backend.service.port.number===80 || p.backend.service.port.name==='http')))")
[ "$ok" = "true" ] || fail "Add a rule for host shop.example.com: path / (pathType Prefix) to Service web, port 80. Backends use service.name and service.port."
