. "$LAB_LIB"
[ -f merged.yaml ] || fail "merged.yaml does not exist yet."
[ -f values-prod.yaml ] && [ -f shop/values.yaml ] || fail "values-prod.yaml and shop/values.yaml are needed to work out the merge."
msg=$(node -e '
const fs = require("fs"), y = require(process.argv[1] + "/node_modules/js-yaml");
const die = (m) => { console.log(m); process.exit(1); };
const load = (f) => { try { return y.load(fs.readFileSync(f, "utf8")); } catch (e) { die(f + " is not valid YAML."); } };
const m = load(process.argv[2]), o = load(process.argv[3]), b = load(process.argv[4]);
const obj = (v) => v && typeof v === "object" && !Array.isArray(v);
const merge = (x, z) => { const r = { ...x }; for (const k of Object.keys(z)) r[k] = obj(z[k]) && obj(x[k]) ? merge(x[k], z[k]) : z[k]; return r; };
const canon = (v) => obj(v) ? "{" + Object.keys(v).sort().map((k) => JSON.stringify(k) + ":" + canon(v[k])).join(",") + "}" : Array.isArray(v) ? "[" + v.map(canon).join(",") + "]" : JSON.stringify(String(v));
if (!obj(m)) die("merged.yaml should be a YAML map.");
const want = merge(b || {}, o || {});
if (canon(m) !== canon(want)) {
  for (const k of Object.keys(want)) if (!(k in m)) die("merged.yaml is missing " + k + ".");
  for (const k of Object.keys(m)) if (!(k in want)) die("merged.yaml has " + k + ", which is in neither file.");
  die("merged.yaml does not match what the two files merge to: check each value, including the nested ones.");
}
' "${LAB_LIB%/labs/lib.sh}" merged.yaml values-prod.yaml shop/values.yaml) || fail "$msg"
