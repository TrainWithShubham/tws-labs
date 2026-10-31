. "$LAB_LIB"
f=app/replicaset.yaml
[ -f "$f" ] || fail "app/replicaset.yaml does not exist."
r=$(yaml_get "$f" '(() => { try {
  if (d.kind !== "ReplicaSet") return "app/replicaset.yaml should stay a ReplicaSet.";
  if (d.spec.replicas !== 3) return "spec.replicas should be the number 3 (currently " + JSON.stringify(d.spec.replicas) + ").";
  const s = d.spec.selector.matchLabels;
  const t = d.spec.template.metadata.labels;
  if (!s || !t || !Object.keys(s).length) return "The selector or template labels are missing.";
  for (const k of Object.keys(s)) if (t[k] !== s[k]) return "The selector no longer matches the template labels.";
  return "ok";
} catch (e) { return "app/replicaset.yaml is missing spec.selector or spec.template."; } })()')
[ "$r" = ok ] || fail "${r:-app/replicaset.yaml is not valid YAML.}"
