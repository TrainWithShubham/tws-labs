. "$LAB_LIB"
f=app/deployment.yaml
[ -f "$f" ] || fail "app/deployment.yaml does not exist."
r=$(yaml_get "$f" '(() => { try {
  const c = d.spec.template.spec.containers[0];
  const s = d.spec.strategy;
  if (!s) return "spec.strategy is missing.";
  if (s.type !== "RollingUpdate") return "strategy.type should be RollingUpdate.";
  const ru = s.rollingUpdate;
  if (!ru) return "Add a rollingUpdate block with maxUnavailable and maxSurge.";
  // Kubernetes rounds a percentage of the replica count: maxSurge up, maxUnavailable down.
  const r = Number.isInteger(d.spec.replicas) ? d.spec.replicas : 1;
  const n = (v, round) => { if (typeof v === "number") return v; const m = /^([0-9]+)%$/.exec(String(v)); return m ? round(Number(m[1]) * r / 100) : NaN; };
  if (!(n(ru.maxUnavailable, Math.floor) === 0)) return "maxUnavailable should work out to 0 so capacity never drops.";
  if (!(n(ru.maxSurge, Math.ceil) > 0)) return "With maxUnavailable 0, maxSurge must be above 0 or the rollout cannot move.";
  return "ok";
} catch (e) { return "The Deployment is missing spec.template.spec.containers."; } })()')
[ "$r" = ok ] || fail "${r:-app/deployment.yaml is not valid YAML.}"
