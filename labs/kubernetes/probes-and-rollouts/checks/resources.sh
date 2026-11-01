. "$LAB_LIB"
f=app/deployment.yaml
[ -f "$f" ] || fail "app/deployment.yaml does not exist."
r=$(yaml_get "$f" '(() => { try {
  const c = d.spec.template.spec.containers[0];
  const rs = c.resources;
  if (!rs || !rs.requests || !rs.limits) return "The web container needs resources.requests and resources.limits.";
  const mult = { "": 1, m: 0.001, k: 1e3, M: 1e6, G: 1e9, T: 1e12, Ki: 1024, Mi: 1048576, Gi: 1073741824, Ti: 1099511627776 };
  const q = (v) => { if (typeof v === "number") return v; const m = /^([0-9]*\.?[0-9]+)(m|k|M|G|T|Ki|Mi|Gi|Ti)?$/.exec(String(v)); return m ? parseFloat(m[1]) * mult[m[2] || ""] : NaN; };
  const same = (a, b) => Math.abs(q(a) - b) <= 1e-9 * Math.max(1, b);
  if (!same(rs.requests.cpu, 0.1)) return "requests.cpu should be 100m (0.1 of a core).";
  if (!same(rs.requests.memory, 128 * 1048576)) return "requests.memory should be 128Mi (lowercase m means milli, not mega).";
  if (!same(rs.limits.cpu, 0.5)) return "limits.cpu should be 500m (half a core).";
  if (!same(rs.limits.memory, 256 * 1048576)) return "limits.memory should be 256Mi (lowercase m means milli, not mega).";
  return "ok";
} catch (e) { return "The Deployment is missing spec.template.spec.containers."; } })()')
[ "$r" = ok ] || fail "${r:-app/deployment.yaml is not valid YAML.}"
