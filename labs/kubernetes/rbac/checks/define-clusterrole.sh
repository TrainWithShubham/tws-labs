. "$LAB_LIB"

f="app/node-viewer-clusterrole.yaml"
[ -f "$f" ] || fail "app/node-viewer-clusterrole.yaml does not exist."

kind=$(yaml_get "$f" 'd && d.kind')
[ "$kind" = "ClusterRole" ] || fail "The kind should be ClusterRole."

api=$(yaml_get "$f" 'd && d.apiVersion')
[ "$api" = "rbac.authorization.k8s.io/v1" ] || fail "The apiVersion should be rbac.authorization.k8s.io/v1."

name=$(yaml_get "$f" 'd && d.metadata && d.metadata.name')
[ "$name" = "node-viewer" ] || fail "Set metadata.name to node-viewer."

ns_field=$(yaml_get "$f" 'd && d.metadata && d.metadata.namespace')
[ -z "$ns_field" ] || [ "$ns_field" = "null" ] || [ "$ns_field" = "undefined" ] || fail "ClusterRole is cluster-scoped and must not define metadata.namespace."

err=$(yaml_get "$f" '(() => {
  if (!d || !Array.isArray(d.rules) || d.rules.length === 0) return "The rules list is missing in app/node-viewer-clusterrole.yaml.";
  const allowedGroups = new Set([""]);
  const allowedResources = new Set(["nodes"]);
  const allowedVerbs = new Set(["get", "list"]);
  const granted = new Set();
  for (const rule of d.rules) {
    if (!rule || typeof rule !== "object") return "Invalid rule entry in rules.";
    if (!Array.isArray(rule.apiGroups) || rule.apiGroups.length === 0) return "Each rule must specify apiGroups.";
    if (!Array.isArray(rule.resources) || rule.resources.length === 0) return "Each rule must specify resources.";
    if (!Array.isArray(rule.verbs) || rule.verbs.length === 0) return "Each rule must specify verbs.";
    for (const g of rule.apiGroups) {
      if (!allowedGroups.has(g)) return "ClusterRole must only grant permissions in core apiGroup \"\" (found: " + g + ").";
    }
    for (const res of rule.resources) {
      if (!allowedResources.has(res)) return "ClusterRole must only grant access to nodes (found: " + res + ").";
    }
    for (const v of rule.verbs) {
      if (!allowedVerbs.has(v)) return "ClusterRole must only grant get and list verbs (found: " + v + ").";
    }
    for (const res of rule.resources) {
      for (const v of rule.verbs) granted.add(`${res}:${v}`);
    }
  }
  const required = ["nodes:get", "nodes:list"];
  for (const req of required) {
    if (!granted.has(req)) {
      const [r, v] = req.split(":");
      return `Missing permission: verb "${v}" for resource "${r}".`;
    }
  }
  return "OK";
})()')

[ "$err" = "OK" ] || fail "$err"
