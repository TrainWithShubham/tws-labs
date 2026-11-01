. "$LAB_LIB"

f="app/blog-ingress.yaml"
[ -f "$f" ] || fail "app/blog-ingress.yaml does not exist."
msg=$(node -e '
const y = require(process.argv[1] + "/node_modules/js-yaml"), fs = require("fs");
const load = p => y.load(fs.readFileSync(p, "utf8"));
try {
  const ing = load("app/blog-ingress.yaml");
  const svcs = {};
  for (const p of ["app/web-service.yaml", "app/api-service.yaml"]) { const s = load(p); svcs[s.metadata.name] = s.spec.ports; }
  if (!svcs.web.some(p => p.port === 80) || !svcs.api.some(p => p.port === 8080)) { console.log("Leave the Service files alone; fix the Ingress."); process.exit(0); }
  if (ing.kind !== "Ingress" || ing.apiVersion !== "networking.k8s.io/v1") { console.log("app/blog-ingress.yaml should stay a networking.k8s.io/v1 Ingress."); process.exit(0); }
  const paths = [];
  for (const r of (ing.spec && ing.spec.rules) || []) for (const p of ((r.http || {}).paths || [])) paths.push(p);
  const want = { "/": "web", "/api": "api" };
  for (const [path, svc] of Object.entries(want)) {
    const p = paths.find(x => x.path === path);
    if (!p) { console.log("Keep a rule for path " + path + " (it should reach Service " + svc + ")."); process.exit(0); }
    const b = (p.backend || {}).service || {};
    if (!svcs[b.name]) { console.log("Path " + path + " points at Service \"" + b.name + "\", which does not exist. Look at the names in the app/*-service.yaml files."); process.exit(0); }
    if (b.name !== svc) { console.log("Path " + path + " should reach the " + svc + " Service."); process.exit(0); }
    const port = b.port || {};
    if (!svcs[b.name].some(sp => (port.number !== undefined && sp.port === port.number) || (port.name !== undefined && sp.name === port.name))) { console.log("Service " + b.name + " does not expose the port that path " + path + " asks for."); process.exit(0); }
  }
} catch (e) { console.log("app/blog-ingress.yaml is not valid YAML or a Service file is damaged."); }
' "${LAB_LIB%/labs/lib.sh}" 2>/dev/null)
[ -z "$msg" ] || fail "$msg"
