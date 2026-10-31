. "$LAB_LIB"
f=app/deployment.yaml
[ -f "$f" ] || fail "app/deployment.yaml does not exist."
r=$(yaml_get "$f" '(() => { try {
  const s = d.spec.selector && d.spec.selector.matchLabels;
  const t = d.spec.template.metadata && d.spec.template.metadata.labels;
  if (!s || !Object.keys(s).length) return "spec.selector.matchLabels is missing or empty.";
  if (!t) return "The Pod template has no labels.";
  for (const k of Object.keys(s)) if (String(t[k]) !== String(s[k])) return "The selector wants " + k + ": " + s[k] + " but the template has " + k + ": " + t[k] + ".";
  if (t.app !== "web") return "The Service looks for app: web, so the template must carry it.";
  return "ok";
} catch (e) { return "app/deployment.yaml is missing spec.selector or spec.template."; } })()')
[ "$r" = ok ] || fail "${r:-app/deployment.yaml is not valid YAML.}"
