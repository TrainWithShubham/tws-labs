. "$LAB_LIB"
f=app/pod.yaml
[ -f "$f" ] || fail "app/pod.yaml does not exist."
kind=$(yaml_get "$f" 'd.kind')
[ "$kind" = "Pod" ] || fail "The kind should be Pod."
api=$(yaml_get "$f" 'd.apiVersion')
[ "$api" = "v1" ] || fail "The apiVersion should be v1."

name=$(yaml_get "$f" 'd.metadata && d.metadata.name')
[ "$name" = "web-pod" ] || fail "Name the Pod web-pod in metadata.name."

label=$(yaml_get "$f" 'd.metadata && d.metadata.labels && d.metadata.labels.app')
[ "$label" = "web" ] || fail "Set metadata.labels.app to web."

containers=$(yaml_get "$f" 'JSON.stringify(d.spec && d.spec.containers)')
[ -n "$containers" ] && [ "$containers" != "null" ] || fail "spec.containers list is missing."

c=$(echo "$containers" | jq -c '.[]? | select((.image // "") | test("^nginx(:1\\.27)?$"))')
[ -n "$c" ] || fail "Add a container using image nginx:1.27."
