. "$LAB_LIB"

f="app/development-ns.yaml"
[ -f "$f" ] || fail "app/development-ns.yaml does not exist."

kind=$(yaml_get "$f" 'd && d.kind')
[ "$kind" = "Namespace" ] || fail "The kind should be Namespace."

api=$(yaml_get "$f" 'd && d.apiVersion')
[ "$api" = "v1" ] || fail "The apiVersion should be v1."

name=$(yaml_get "$f" 'd && d.metadata && d.metadata.name')
[ "$name" = "development" ] || fail "Set metadata.name to development."

ns_field=$(yaml_get "$f" 'd && d.metadata && d.metadata.namespace')
[ -z "$ns_field" ] || [ "$ns_field" = "null" ] || [ "$ns_field" = "undefined" ] || fail "A Namespace resource is cluster-scoped and must not define metadata.namespace."

