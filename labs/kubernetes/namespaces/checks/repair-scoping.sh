. "$LAB_LIB"

ns_file="app/monitoring-ns.yaml"
cm_file="app/app-config.yaml"

[ -f "$ns_file" ] || fail "app/monitoring-ns.yaml does not exist."
[ -f "$cm_file" ] || fail "app/app-config.yaml does not exist."

# Validate Namespace
[ "$(yaml_get "$ns_file" 'd && d.kind')" = "Namespace" ] || fail "app/monitoring-ns.yaml kind must be Namespace."
[ "$(yaml_get "$ns_file" 'd && d.apiVersion')" = "v1" ] || fail "app/monitoring-ns.yaml apiVersion must be v1."
[ "$(yaml_get "$ns_file" 'd && d.metadata && d.metadata.name')" = "monitoring" ] || fail "app/monitoring-ns.yaml metadata.name must be monitoring."

ns_scope=$(yaml_get "$ns_file" 'd && d.metadata && d.metadata.namespace')
[ -z "$ns_scope" ] || [ "$ns_scope" = "null" ] || [ "$ns_scope" = "undefined" ] || fail "Remove metadata.namespace from app/monitoring-ns.yaml: Namespaces are cluster-scoped."

# Validate ConfigMap
[ "$(yaml_get "$cm_file" 'd && d.kind')" = "ConfigMap" ] || fail "app/app-config.yaml kind must be ConfigMap."
[ "$(yaml_get "$cm_file" 'd && d.apiVersion')" = "v1" ] || fail "app/app-config.yaml apiVersion must be v1."
[ "$(yaml_get "$cm_file" 'd && d.metadata && d.metadata.name')" = "app-config" ] || fail "app/app-config.yaml metadata.name must be app-config."
[ "$(yaml_get "$cm_file" 'd && d.metadata && d.metadata.namespace')" = "development" ] || fail "Add metadata.namespace: development to app/app-config.yaml."

has_data=$(yaml_get "$cm_file" 'Boolean(d && d.data && d.data.APP_ENV === "development" && d.data.LOG_LEVEL === "debug")')
[ "$has_data" = "true" ] || fail "Preserve data entries APP_ENV and LOG_LEVEL in app/app-config.yaml."

