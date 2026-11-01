. "$LAB_LIB"
t=shop/templates/deployment.yaml
[ -f "$t" ] || fail "shop/templates/deployment.yaml does not exist yet."
[ -f shop/values.yaml ] || fail "shop/values.yaml is missing: the template needs something to read."
msg=$(node -e '
const fs = require("fs"), y = require(process.argv[1] + "/node_modules/js-yaml");
const die = (m) => { console.log(m); process.exit(1); };
let vals; try { vals = y.load(fs.readFileSync(process.argv[3], "utf8")); } catch (e) { die("values.yaml is not valid YAML."); }
const raw = fs.readFileSync(process.argv[2], "utf8");
const t = raw.replace(/\{\{-?\s*\/\*[\s\S]*?\*\/\s*-?\}\}/g, "");
if ((t.match(/\{\{/g) || []).length !== (t.match(/\}\}/g) || []).length) die("The {{ and }} do not pair up.");
const body = t.split("\n").filter((l) => !/^\s*#/.test(l)).map((l) => l.replace(/\s+#[^"]*$/, "")).join("\n");
if (!/^apiVersion:\s*apps\/v1\s*$/m.test(body)) die("The template should start like a Deployment: apiVersion: apps/v1.");
if (!/^kind:\s*Deployment\s*$/m.test(body)) die("kind should be Deployment.");
if (!/^\s*name:.*\{\{[^}]*\.Release\.Name/m.test(body)) die("metadata.name should come from {{ .Release.Name }}.");
if (!/^\s*replicas:.*\{\{[^}]*\.Values\.replicaCount/m.test(body)) die("replicas: should read .Values.replicaCount.");
if (!/^\s*(-\s*)?image:.*\.Values\.image\.repository.*\.Values\.image\.tag/m.test(body)) die("image: should be built from .Values.image.repository and .Values.image.tag.");
if (!/\{\{-?[^}]*\|\s*(default|quote)\b[^}]*\}\}/.test(body)) die("Use a pipeline somewhere: {{ ... | default ... }} or {{ ... | quote }}.");
const re = /\.Values((?:\.[A-Za-z_][A-Za-z0-9_]*)+)/g; let m;
while ((m = re.exec(t))) {
  let cur = vals; const path = m[1].slice(1).split(".");
  for (const k of path) { if (cur && typeof cur === "object" && Object.prototype.hasOwnProperty.call(cur, k)) cur = cur[k]; else die("The template reads .Values." + path.join(".") + " but values.yaml has no such key."); }
}
' "${LAB_LIB%/labs/lib.sh}" "$t" shop/values.yaml) || fail "$msg"
