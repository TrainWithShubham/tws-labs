. "$LAB_LIB"

claim="app/reports-pvc.yaml"
pv="app/pv.yaml"
[ -f "$claim" ] || fail "app/reports-pvc.yaml is missing."
[ -f "$pv" ] || fail "app/pv.yaml is missing."

# Apply the binding rule to the two manifests: same StorageClass, enough capacity, every requested access mode offered.
# Prints OK, or one line saying what does not fit. The PV must still be the one from the first task.
verdict=$(node -e '
const y = require(process.argv[1] + "/node_modules/js-yaml");
const fs = require("fs");
const load = (f) => { try { return y.load(fs.readFileSync(f, "utf8")); } catch (e) { return null; } };
const units = { "": 1, k: 1e3, K: 1e3, M: 1e6, G: 1e9, T: 1e12, Ki: 1024, Mi: 1024 ** 2, Gi: 1024 ** 3, Ti: 1024 ** 4 };
const bytes = (q) => {
  const m = /^([0-9]+(?:\.[0-9]+)?)(Ki|Mi|Gi|Ti|k|K|M|G|T)?$/.exec(String(q === undefined ? "" : q));
  return m ? Number(m[1]) * units[m[2] || ""] : NaN;
};
const c = load(process.argv[2]), p = load(process.argv[3]);
const out = (s) => { console.log(s); process.exit(0); };
if (!c || typeof c !== "object") out("app/reports-pvc.yaml is not valid YAML.");
if (!p || typeof p !== "object") out("app/pv.yaml is not valid YAML.");
const cs = c.spec || {}, ps = p.spec || {};
const pvModes = Array.isArray(ps.accessModes) ? ps.accessModes : [];
const pvSize = bytes(ps.capacity && ps.capacity.storage);
if (!(p.metadata && p.metadata.name === "local-pv") || pvSize !== 1024 ** 3 || pvModes.length !== 1 || pvModes[0] !== "ReadWriteOnce" || ps.storageClassName !== "")
  out("Leave app/pv.yaml as it was (local-pv, 1Gi, ReadWriteOnce): the claim is what needs to change.");
if (c.kind !== "PersistentVolumeClaim") out("app/reports-pvc.yaml must stay a PersistentVolumeClaim.");
if (!(c.metadata && c.metadata.name === "reports-data")) out("Keep the claim name reports-data.");
if (cs.storageClassName !== "") out("The claim must keep storageClassName: \"\" so it matches the PV, which has no class.");
if (cs.volumeName !== undefined && cs.volumeName !== "local-pv") out("The claim names a different volume than local-pv.");
const want = bytes(cs.resources && cs.resources.requests && cs.resources.requests.storage);
if (!(want > 0)) out("The claim needs a storage request under spec.resources.requests.");
const modes = Array.isArray(cs.accessModes) ? cs.accessModes : [];
if (modes.length === 0) out("The claim needs at least one access mode.");
const missing = modes.filter((m) => !pvModes.includes(m));
if (missing.length) out("The claim asks for " + missing.join(", ") + ", but local-pv only offers ReadWriteOnce.");
if (want > pvSize) out("The claim requests more storage than local-pv has (1Gi).");
out("OK");
' "${LAB_LIB%/labs/lib.sh}" "$claim" "$pv" 2>/dev/null)

[ "$verdict" = "OK" ] || fail "${verdict:-Could not read the two manifests.}"
