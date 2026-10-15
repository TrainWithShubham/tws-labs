. "$LAB_LIB"
f=app/configmap.yaml
[ -f "$f" ] || fail "app/configmap.yaml does not exist."
[ "$(yaml_get "$f" 'd.kind')" = "ConfigMap" ] || fail "The kind should be ConfigMap."
[ "$(yaml_get "$f" 'd.apiVersion')" = "v1" ] || fail "The apiVersion of a ConfigMap is v1."
[ "$(yaml_get "$f" 'd.metadata && d.metadata.name')" = "app-config" ] || fail "Name the ConfigMap app-config."
[ "$(yaml_get "$f" 'd.data && d.data.LOG_LEVEL')" = "debug" ] || fail "Set data.LOG_LEVEL to debug."
[ "$(yaml_get "$f" 'd.data && d.data.GREETING')" = "hello" ] || fail "Set data.GREETING to hello."
