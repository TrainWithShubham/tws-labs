. "$LAB_LIB"
f=app/pod.yaml
[ -f "$f" ] || fail "app/pod.yaml does not exist."
r=$(yaml_get "$f" '(() => { try {
  if (d.kind !== "Pod") return "app/pod.yaml should stay a Pod.";
  const l = d.metadata && d.metadata.labels;
  if (!l) return "The Pod has no labels under metadata yet.";
  if (l.app !== "web") return "metadata.labels needs app: web.";
  if (l.env !== "prod") return "metadata.labels needs env: prod.";
  return "ok";
} catch (e) { return "app/pod.yaml is not shaped like a Pod."; } })()')
[ "$r" = ok ] || fail "${r:-app/pod.yaml is not valid YAML.}"
