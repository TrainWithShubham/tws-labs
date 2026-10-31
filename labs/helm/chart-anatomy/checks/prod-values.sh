. "$LAB_LIB"
f=values-prod.yaml
[ -f "$f" ] || fail "values-prod.yaml does not exist yet (create it next to the shop folder)."
[ -f shop/values.yaml ] || fail "shop/values.yaml is missing."
msg=$(node -e '
const fs = require("fs"), y = require(process.argv[1] + "/node_modules/js-yaml");
const die = (m) => { console.log(m); process.exit(1); };
let o, b;
try { o = y.load(fs.readFileSync(process.argv[2], "utf8")); } catch (e) { die("values-prod.yaml is not valid YAML."); }
try { b = y.load(fs.readFileSync(process.argv[3], "utf8")); } catch (e) { die("shop/values.yaml is not valid YAML."); }
if (!o || typeof o !== "object") die("values-prod.yaml is empty.");
const obj = (v) => v && typeof v === "object" && !Array.isArray(v);
const walk = (ov, bv, p) => { for (const k of Object.keys(ov)) {
  if (!obj(bv) || !Object.prototype.hasOwnProperty.call(bv, k)) die("values-prod.yaml sets " + p + k + ", which is not a key in shop/values.yaml.");
  if (obj(ov[k])) walk(ov[k], bv[k], p + k + "."); } };
walk(o, b, "");
if (o.replicaCount !== 3) die("replicaCount should be 3 in the override.");
if (!o.image || o.image.tag === undefined || o.image.tag === null || String(o.image.tag).length === 0) die("Override image.tag (an image: map with tag inside).");
if (String(o.image.tag) === String(b.image && b.image.tag)) die("image.tag is the same as the default: pick a different version.");
' "${LAB_LIB%/labs/lib.sh}" "$f" shop/values.yaml) || fail "$msg"
