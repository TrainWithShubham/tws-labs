. "$LAB_LIB"
f=app/deployment.yaml
[ -f "$f" ] || fail "app/deployment.yaml does not exist."
r=$(yaml_get "$f" '(() => { try {
  const c = d.spec.template.spec.containers[0];
  const p = c.livenessProbe;
  if (!p) return "The web container has no livenessProbe yet.";
  if (!p.httpGet) return "livenessProbe should use httpGet.";
  if (p.httpGet.path !== "/healthz") return "livenessProbe path should be /healthz.";
  if (p.httpGet.port !== 80 && p.httpGet.port !== "http") return "livenessProbe should target the container port (80, or its name http).";
  if (!(p.initialDelaySeconds >= 10)) return "Set initialDelaySeconds to at least 10 so a slow start is not killed.";
  if (p.periodSeconds !== undefined && p.periodSeconds < 5) return "periodSeconds under 5 is aggressive for a liveness probe.";
  if (p.failureThreshold !== undefined && p.failureThreshold < 3) return "Allow at least 3 failures (the default) before restarting.";
  return "ok";
} catch (e) { return "The Deployment is missing spec.template.spec.containers."; } })()')
[ "$r" = ok ] || fail "${r:-app/deployment.yaml is not valid YAML.}"
