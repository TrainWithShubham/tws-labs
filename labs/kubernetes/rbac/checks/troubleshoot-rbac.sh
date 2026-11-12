. "$LAB_LIB"

f="app/deploy-manager-role.yaml"
[ -f "$f" ] || fail "app/deploy-manager-role.yaml does not exist."

kind=$(yaml_get "$f" 'd && d.kind')
[ "$kind" = "Role" ] || fail "The kind should be Role."

api=$(yaml_get "$f" 'd && d.apiVersion')
[ "$api" = "rbac.authorization.k8s.io/v1" ] || fail "The apiVersion should be rbac.authorization.k8s.io/v1."

name=$(yaml_get "$f" 'd && d.metadata && d.metadata.name')
[ "$name" = "deployment-manager" ] || fail "Keep metadata.name as deployment-manager."

ns=$(yaml_get "$f" 'd && d.metadata && d.metadata.namespace')
[ "$ns" = "development" ] || fail "Keep metadata.namespace as development."

valid_rules=$(yaml_get "$f" 'Boolean(d && Array.isArray(d.rules) && d.rules.length === 1 && (() => {
  const rule = d.rules[0];
  const exactValues = (actual, expected) => Array.isArray(actual) && actual.length === expected.length && expected.every(value => actual.includes(value));
  return rule && exactValues(rule.apiGroups, ["apps"]) && exactValues(rule.resources, ["deployments"]) && exactValues(rule.verbs, ["get", "list", "watch", "create"]);
})())')
[ "$valid_rules" = "true" ] || fail "Keep exactly one rule: apiGroups [\"apps\"], resource deployments, and verbs get, list, watch, and create."
