. "$LAB_LIB"

f="app/pod-reader-binding.yaml"
[ -f "$f" ] || fail "app/pod-reader-binding.yaml does not exist."

kind=$(yaml_get "$f" 'd && d.kind')
[ "$kind" = "RoleBinding" ] || fail "The kind should be RoleBinding."

api=$(yaml_get "$f" 'd && d.apiVersion')
[ "$api" = "rbac.authorization.k8s.io/v1" ] || fail "The apiVersion should be rbac.authorization.k8s.io/v1."

name=$(yaml_get "$f" 'd && d.metadata && d.metadata.name')
[ "$name" = "read-pods-binding" ] || fail "Set metadata.name to read-pods-binding."

ns=$(yaml_get "$f" 'd && d.metadata && d.metadata.namespace')
[ "$ns" = "development" ] || fail "Set metadata.namespace to development."

has_exact_subject=$(yaml_get "$f" 'Boolean(d && Array.isArray(d.subjects) && d.subjects.length === 1 && d.subjects[0] && d.subjects[0].kind === "ServiceAccount" && d.subjects[0].name === "app-viewer" && d.subjects[0].namespace === "development")')
[ "$has_exact_subject" = "true" ] || fail "Subjects must contain only ServiceAccount app-viewer in namespace development."

role_kind=$(yaml_get "$f" 'd && d.roleRef && d.roleRef.kind')
[ "$role_kind" = "Role" ] || fail "Set roleRef.kind to Role."

role_name=$(yaml_get "$f" 'd && d.roleRef && d.roleRef.name')
[ "$role_name" = "pod-reader" ] || fail "Set roleRef.name to pod-reader."

role_api=$(yaml_get "$f" 'd && d.roleRef && d.roleRef.apiGroup')
[ "$role_api" = "rbac.authorization.k8s.io" ] || fail "Set roleRef.apiGroup to rbac.authorization.k8s.io."
