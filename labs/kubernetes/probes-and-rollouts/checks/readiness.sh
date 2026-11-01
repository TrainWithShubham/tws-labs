. "$LAB_LIB"
f=app/deployment.yaml
[ -f "$f" ] || fail "app/deployment.yaml does not exist."
r=$(yaml_get "$f" '(() => { try {
  const c = d.spec.template.spec.containers[0];
  const p = c.readinessProbe;
  if (!p) return "The web container has no readinessProbe yet.";
  if (!p.httpGet) return "readinessProbe should use httpGet.";
  if (p.httpGet.path !== "/ready") return "readinessProbe path should be /ready.";
  if (p.httpGet.port !== 80 && p.httpGet.port !== "http") return "readinessProbe should target the container port (80, or its name http).";
  if (!(p.periodSeconds >= 1 && p.periodSeconds <= 10)) return "Set periodSeconds between 1 and 10 on the readinessProbe.";
  return "ok";
} catch (e) { return "The Deployment is missing spec.template.spec.containers."; } })()')
[ "$r" = ok ] || fail "${r:-app/deployment.yaml is not valid YAML.}"
