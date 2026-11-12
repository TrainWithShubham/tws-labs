. "$LAB_LIB"

f="app/pod-reader-role.yaml"
[ -f "$f" ] || fail "app/pod-reader-role.yaml does not exist."

kind=$(yaml_get "$f" 'd && d.kind')
[ "$kind" = "Role" ] || fail "The kind should be Role."

api=$(yaml_get "$f" 'd && d.apiVersion')
[ "$api" = "rbac.authorization.k8s.io/v1" ] || fail "The apiVersion should be rbac.authorization.k8s.io/v1."

name=$(yaml_get "$f" 'd && d.metadata && d.metadata.name')
[ "$name" = "pod-reader" ] || fail "Set metadata.name to pod-reader."

ns=$(yaml_get "$f" 'd && d.metadata && d.metadata.namespace')
[ "$ns" = "development" ] || fail "Set metadata.namespace to development."

err=$(yaml_get "$f" '(() => {
  if (!d || !Array.isArray(d.rules) || d.rules.length === 0) return "The rules list is missing in app/pod-reader-role.yaml.";
  const allowedGroups = new Set([""]);
  const allowedResources = new Set(["pods", "configmaps"]);
  const allowedVerbs = new Set(["get", "list", "watch"]);
  const granted = new Set();
  for (const rule of d.rules) {
    if (!rule || typeof rule !== "object") return "Invalid rule entry in rules.";
    if (!Array.isArray(rule.apiGroups) || rule.apiGroups.length === 0) return "Each rule must specify apiGroups.";
    if (!Array.isArray(rule.resources) || rule.resources.length === 0) return "Each rule must specify resources.";
    if (!Array.isArray(rule.verbs) || rule.verbs.length === 0) return "Each rule must specify verbs.";
    for (const g of rule.apiGroups) {
      if (!allowedGroups.has(g)) return "Role must only grant permissions in core apiGroup \"\" (found: " + g + ").";
    }
    for (const res of rule.resources) {
      if (!allowedResources.has(res)) return "Role must only grant access to pods and configmaps (found: " + res + ").";
    }
    for (const v of rule.verbs) {
      if (!allowedVerbs.has(v)) return "Role must only grant get, list, and watch verbs (found: " + v + ").";
    }
    for (const res of rule.resources) {
      for (const v of rule.verbs) granted.add(`${res}:${v}`);
    }
  }
  const required = ["pods:get", "pods:list", "pods:watch", "configmaps:get", "configmaps:list", "configmaps:watch"];
  for (const req of required) {
    if (!granted.has(req)) {
      const [r, v] = req.split(":");
      return `Missing permission: verb "${v}" for resource "${r}".`;
    }
  }
  return "OK";
})()')

[ "$err" = "OK" ] || fail "$err"
