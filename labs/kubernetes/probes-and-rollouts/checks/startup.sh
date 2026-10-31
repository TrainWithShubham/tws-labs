. "$LAB_LIB"
f=app/deployment.yaml
[ -f "$f" ] || fail "app/deployment.yaml does not exist."
r=$(yaml_get "$f" '(() => { try {
  const c = d.spec.template.spec.containers[0];
  const p = c.startupProbe;
  if (!p) return "The web container has no startupProbe yet.";
  if (!p.httpGet) return "startupProbe should use httpGet.";
  if (p.httpGet.path !== "/healthz") return "startupProbe path should be /healthz.";
  if (p.httpGet.port !== 80 && p.httpGet.port !== "http") return "startupProbe should target the container port (80, or its name http).";
  const per = p.periodSeconds === undefined ? 10 : p.periodSeconds;
  const ft = p.failureThreshold === undefined ? 3 : p.failureThreshold;
  if (per * ft < 60) return "The start-up budget is failureThreshold x periodSeconds = " + (per * ft) + "s; allow at least 60s.";
  return "ok";
} catch (e) { return "The Deployment is missing spec.template.spec.containers."; } })()')
[ "$r" = ok ] || fail "${r:-app/deployment.yaml is not valid YAML.}"
