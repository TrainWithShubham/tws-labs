. "$LAB_LIB"
f=app/service.yaml
[ -f "$f" ] || fail "app/service.yaml does not exist."
r=$(yaml_get "$f" '(() => { try {
  if (d.kind !== "Service") return "app/service.yaml should stay a Service.";
  const s = d.spec.selector;
  if (!s || !Object.keys(s).length) return "spec.selector is missing: the Service routes to nothing.";
  const have = { app: "web", tier: "frontend" };
  for (const k of Object.keys(s)) if (have[k] !== s[k]) return "No Pod has the label " + k + ": " + s[k] + ".";
  if (s.app !== "web") return "Select the Pods by app: web.";
  return "ok";
} catch (e) { return "app/service.yaml has no spec section."; } })()')
[ "$r" = ok ] || fail "${r:-app/service.yaml is not valid YAML.}"
