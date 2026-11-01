. "$LAB_LIB"
f=guestbook-app.yaml
[ -f "$f" ] || fail "guestbook-app.yaml does not exist."
[ -n "$(yaml_get "$f" 'd && typeof d === "object" ? 1 : ""')" ] || fail "guestbook-app.yaml is not valid YAML."
[ "$(yaml_get "$f" 'd.spec && typeof d.spec.destination')" = "object" ] || fail "spec.destination is missing."
srv=$(yaml_get "$f" 'd.spec.destination.server')
nm=$(yaml_get "$f" 'd.spec.destination.name')
if [ "$srv" != "undefined" ] && [ -n "$srv" ] && [ "$nm" != "undefined" ] && [ -n "$nm" ]; then
  fail "destination takes either server or name, not both."
fi
if [ "$srv" = "https://kubernetes.default.svc" ] || { [ "$srv" = "undefined" ] && [ "$nm" = "in-cluster" ]; }; then :; else
  fail "destination.server should be https://kubernetes.default.svc (the in-cluster API)."
fi
[ "$(yaml_get "$f" 'd.spec.destination.namespace')" = "guestbook" ] || fail "destination.namespace should be guestbook."
