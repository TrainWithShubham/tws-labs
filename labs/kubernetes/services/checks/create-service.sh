. "$LAB_LIB"

f="app/service.yaml"
[ -f "$f" ] || fail "app/service.yaml does not exist."

kind=$(yaml_get "$f" 'd.kind')
[ "$kind" = "Service" ] || fail "The kind should be Service."

api=$(yaml_get "$f" 'd.apiVersion')
[ "$api" = "v1" ] || fail "The apiVersion should be v1."

name=$(yaml_get "$f" 'd.metadata && d.metadata.name')
[ "$name" = "nginx-service" ] || fail "Name the Service nginx-service in metadata.name."

type=$(yaml_get "$f" 'd.spec && d.spec.type')
[ -z "$type" ] || [ "$type" = "ClusterIP" ] || fail "Set spec.type to ClusterIP (or omit it for default ClusterIP)."

