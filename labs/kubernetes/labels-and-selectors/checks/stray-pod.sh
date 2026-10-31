. "$LAB_LIB"
f=app/stray-pod.yaml
[ -f "$f" ] || fail "app/stray-pod.yaml does not exist."
want=$(yaml_get app/replicaset.yaml 'd.spec.selector.matchLabels.app')
[ -n "$want" ] && [ "$want" != undefined ] || want=worker
r=$(WANT="$want" yaml_get "$f" '(() => { try {
  if (d.kind !== "Pod") return "app/stray-pod.yaml should stay a Pod.";
  const l = (d.metadata && d.metadata.labels) || {};
  if (String(l.app) === "'"$want"'") return "The Pod still has app: " + l.app + ", so the ReplicaSet would adopt it.";
  return "ok";
} catch (e) { return "app/stray-pod.yaml is not shaped like a Pod."; } })()')
[ "$r" = ok ] || fail "${r:-app/stray-pod.yaml is not valid YAML.}"
