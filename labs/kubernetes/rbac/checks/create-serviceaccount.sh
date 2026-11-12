. "$LAB_LIB"

f="app/app-viewer-sa.yaml"
[ -f "$f" ] || fail "app/app-viewer-sa.yaml does not exist."

kind=$(yaml_get "$f" 'd && d.kind')
[ "$kind" = "ServiceAccount" ] || fail "The kind should be ServiceAccount."

api=$(yaml_get "$f" 'd && d.apiVersion')
[ "$api" = "v1" ] || fail "The apiVersion should be v1."

name=$(yaml_get "$f" 'd && d.metadata && d.metadata.name')
[ "$name" = "app-viewer" ] || fail "Set metadata.name to app-viewer."

ns=$(yaml_get "$f" 'd && d.metadata && d.metadata.namespace')
[ "$ns" = "development" ] || fail "Set metadata.namespace to development."
