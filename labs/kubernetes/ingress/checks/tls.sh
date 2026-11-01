. "$LAB_LIB"

f="app/ingress.yaml"
[ -f "$f" ] || fail "app/ingress.yaml does not exist yet."
[ "$(yaml_get "$f" "d.kind")" = "Ingress" ] || fail "The kind should be Ingress."
[ "$(yaml_get "$f" "d.apiVersion")" = "networking.k8s.io/v1" ] || fail "Use apiVersion networking.k8s.io/v1 (the older beta versions were removed)."
paths='(((d.spec||{}).rules||[]).flatMap(r=>((r.http||{}).paths||[]).map(p=>Object.assign({host:r.host},p))))'

secret=app/tls-secret.yaml
want=$(yaml_get "$secret" 'd.metadata && d.metadata.name')
[ -n "$want" ] || fail "app/tls-secret.yaml is missing or damaged; it names the Secret to use."
has_tls=$(yaml_get "$f" 'Boolean(d.spec && Array.isArray(d.spec.tls) && d.spec.tls.length > 0)')
[ "$has_tls" = "true" ] || fail "Add a tls list under spec."
ok=$(yaml_get "$f" "Boolean(d.spec.tls.some(t=>t && t.secretName==='$want' && Array.isArray(t.hosts) && t.hosts.includes('shop.example.com')))")
[ "$ok" = "true" ] || fail "A tls entry needs hosts containing shop.example.com and secretName set to the name of the Secret in app/tls-secret.yaml."
