. "$LAB_LIB"

f="app/node-viewer-binding.yaml"
[ -f "$f" ] || fail "app/node-viewer-binding.yaml does not exist."

kind=$(yaml_get "$f" 'd && d.kind')
[ "$kind" = "ClusterRoleBinding" ] || fail "The kind should be ClusterRoleBinding."

api=$(yaml_get "$f" 'd && d.apiVersion')
[ "$api" = "rbac.authorization.k8s.io/v1" ] || fail "The apiVersion should be rbac.authorization.k8s.io/v1."

name=$(yaml_get "$f" 'd && d.metadata && d.metadata.name')
[ "$name" = "node-viewer-global-binding" ] || fail "Set metadata.name to node-viewer-global-binding."

ns_field=$(yaml_get "$f" 'd && d.metadata && d.metadata.namespace')
[ -z "$ns_field" ] || [ "$ns_field" = "null" ] || [ "$ns_field" = "undefined" ] || fail "ClusterRoleBinding is cluster-scoped and must not define metadata.namespace."

has_exact_subject=$(yaml_get "$f" 'Boolean(d && Array.isArray(d.subjects) && d.subjects.length === 1 && d.subjects[0] && d.subjects[0].kind === "ServiceAccount" && d.subjects[0].name === "app-viewer" && d.subjects[0].namespace === "development")')
[ "$has_exact_subject" = "true" ] || fail "Subjects must contain only ServiceAccount app-viewer in namespace development."

role_kind=$(yaml_get "$f" 'd && d.roleRef && d.roleRef.kind')
[ "$role_kind" = "ClusterRole" ] || fail "Set roleRef.kind to ClusterRole."

role_name=$(yaml_get "$f" 'd && d.roleRef && d.roleRef.name')
[ "$role_name" = "node-viewer" ] || fail "Set roleRef.name to node-viewer."

role_api=$(yaml_get "$f" 'd && d.roleRef && d.roleRef.apiGroup')
[ "$role_api" = "rbac.authorization.k8s.io" ] || fail "Set roleRef.apiGroup to rbac.authorization.k8s.io."
