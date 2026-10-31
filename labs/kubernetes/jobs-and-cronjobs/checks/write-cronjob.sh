. "$LAB_LIB"

f="batch/cronjob.yaml"
[ -f "$f" ] || fail "batch/cronjob.yaml does not exist yet."
[ "$(yaml_get "$f" 'd.apiVersion')" = "batch/v1" ] || fail "A CronJob uses apiVersion batch/v1."
[ "$(yaml_get "$f" 'd.kind')" = "CronJob" ] || fail "The kind should be CronJob."
[ "$(yaml_get "$f" 'd.metadata && d.metadata.name')" = "nightly-report" ] || fail "Name the CronJob nightly-report in metadata.name."
pod='d.spec && d.spec.jobTemplate && d.spec.jobTemplate.spec && d.spec.jobTemplate.spec.template && d.spec.jobTemplate.spec.template.spec'
[ "$(yaml_get "$f" "Boolean($pod && Array.isArray($pod.containers) && $pod.containers.some(c => c && c.name && c.image))")" = "true" ] || fail "A CronJob wraps a Job: add spec.jobTemplate.spec.template.spec with a named container and an image."
rp=$(yaml_get "$f" "$pod && $pod.restartPolicy")
case "$rp" in
  OnFailure|Never) ;;
  *) fail "The Pod template inside jobTemplate needs restartPolicy OnFailure or Never." ;;
esac
msg=$(node -e '
const y = require(process.argv[1] + "/node_modules/js-yaml"), fs = require("fs");
let d;
try { d = y.load(fs.readFileSync(process.argv[2], "utf8")); } catch (e) { console.log("The file is not valid YAML. Quote the schedule: a bare * is not allowed to start a YAML value."); process.exit(0); }
const s = d && d.spec && d.spec.schedule;
if (typeof s !== "string") { console.log("spec.schedule must be a string such as \"* * * * *\"."); process.exit(0); }
const R = [[0, 59], [0, 23], [1, 31], [1, 12], [0, 7]];
const M = "jan feb mar apr may jun jul aug sep oct nov dec".split(" "), W = "sun mon tue wed thu fri sat".split(" ");
function num(t, i) {
  t = t.toLowerCase();
  if (i === 3 && M.includes(t)) return M.indexOf(t) + 1;
  if (i === 4 && W.includes(t)) return W.indexOf(t);
  return /^[0-9]+$/.test(t) ? Number(t) : NaN;
}
function expand(f, i) {
  const out = new Set(), lo = R[i][0], hi = R[i][1];
  for (const part of f.split(",")) {
    const [range, step, extra] = part.split("/");
    if (extra !== undefined) return null;
    const st = step === undefined ? 1 : Number(step);
    if (!Number.isInteger(st) || st < 1 || !/^[0-9]+$/.test(step === undefined ? "1" : step)) return null;
    let a, b;
    if (range === "*") { a = lo; b = i === 4 ? 6 : hi; }
    else {
      const m = range.split("-");
      if (m.length > 2) return null;
      a = num(m[0], i);
      b = m.length === 2 ? num(m[1], i) : (step === undefined ? a : hi);
    }
    if (!(a >= lo && b <= hi && a <= b)) return null;
    for (let v = a; v <= b; v += st) out.add(i === 4 && v === 7 ? 0 : v);
  }
  return [...out].sort((x, y) => x - y).join(",");
}
function parse(str) {
  const f = str.trim().split(/\s+/);
  return f.length === 5 ? f.map((x, i) => expand(x, i)) : null;
}
const got = parse(s);
if (got === null) { const n = s.trim().split(/\s+/).length; console.log(n !== 5 ? "A schedule has exactly five fields (minute hour day-of-month month day-of-week); yours has " + n + "." : "One field of the schedule is not valid cron syntax."); process.exit(0); }
if (got.some(x => x === null)) { console.log("One field of the schedule is not valid cron syntax."); process.exit(0); }
const want = parse(process.argv[3]);
if (got.join("|") !== want.join("|")) console.log("The schedule is valid, but it does not run at the times the task asks for.");
' "${LAB_LIB%/labs/lib.sh}" "$f" "*/15 * * * *" 2>/dev/null)
[ -z "$msg" ] || fail "$msg"
