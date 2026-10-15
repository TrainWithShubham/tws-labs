// The validator's cases/ step, end to end on a tiny lab: near misses must fail the check, ok- alternatives must pass it.
// Linux only (the validator needs /proc). It runs the lab as the current user (no LAB_UID), so it never shares session user ids with lab-flow.test.js.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const ROOT = path.join(__dirname, '..', '..');
const SKIP = process.platform !== 'linux' && 'the validator needs Linux';

function lab(cases) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'valcases-'));
  fs.chmodSync(root, 0o755);
  fs.copyFileSync(path.join(ROOT, 'labs', 'lib.sh'), path.join(root, 'lib.sh'));
  const d = path.join(root, 't', 'one');
  fs.mkdirSync(path.join(d, 'checks'), { recursive: true });
  fs.mkdirSync(path.join(d, 'solutions'), { recursive: true });
  fs.writeFileSync(path.join(root, 't', 'track.yaml'), 'title: T\ndescription: d\nlabs: [one]\n');
  fs.writeFileSync(path.join(d, 'lab.yaml'), 'title: One\nlevel: beginner\nminutes: 10\nsummary: s\nsteps:\n  - {id: intro, type: lesson, title: Intro, body: hi}\n  - {id: make, type: task, title: Make, body: "Create hello.txt containing hello.", hint: "A nudge that is long enough", success: Done}\n');
  fs.writeFileSync(path.join(d, 'checks', 'make.sh'), '. "$LAB_LIB"\n[ -f hello.txt ] || fail "hello.txt does not exist yet."\n[ "$(cat hello.txt)" = "hello" ] || fail "hello.txt should contain hello."\n');
  fs.writeFileSync(path.join(d, 'solutions', 'make.sh'), 'echo hello > hello.txt\n');
  for (const [name, text] of Object.entries(cases)) {
    fs.mkdirSync(path.join(d, 'cases', 'make'), { recursive: true });
    fs.writeFileSync(path.join(d, 'cases', 'make', `${name}.sh`), text);
  }
  return root;
}
function validate(root) {
  const env = { ...process.env, LABS_DIR: root, SANDBOX_DIR: fs.mkdtempSync(path.join(os.tmpdir(), 'valsb-')) };
  delete env.LAB_UID;
  fs.chmodSync(env.SANDBOX_DIR, 0o755);
  const r = spawnSync(process.execPath, [path.join(ROOT, 'scripts', 'validate-labs.js')], { env, encoding: 'utf8', timeout: 120000 });
  return { status: r.status, out: r.stdout + r.stderr };
}

test('good cases: a near miss fails the check and a valid alternative passes it', { skip: SKIP }, () => {
  const r = validate(lab({ 'wrong-content': 'echo hullo > hello.txt\n', 'wrong-name': 'echo hello > hello.tx\n', 'ok-printf': "printf 'hello\\n' > hello.txt\n" }));
  assert.equal(r.status, 0, r.out);
  assert.match(r.out, /ok\s+case make\/wrong-content \(near miss\)/);
  assert.match(r.out, /ok\s+case make\/ok-printf \(valid alternative\)/);
});

test('a near miss that the check accepts is reported as too lax', { skip: SKIP }, () => {
  const r = validate(lab({ 'actually-right': 'echo hello > hello.txt\n' }));
  assert.equal(r.status, 1);
  assert.match(r.out, /case make\/actually-right: the check PASSES this wrong answer \(too lax\)/);
});

test('a valid alternative that the check rejects is reported as too strict', { skip: SKIP }, () => {
  const r = validate(lab({ 'ok-with-newline': 'echo hello hello > hello.txt\n' }));
  assert.equal(r.status, 1);
  assert.match(r.out, /case make\/ok-with-newline: the check REJECTS this valid alternative \(too strict\): "hello.txt should contain hello."/);
});

test('a malformed case file fails validation instead of being skipped', { skip: SKIP }, () => {
  const r = validate(lab({ heredoc: 'cat > hello.txt <<EOF\nx\nEOF\n' }));
  assert.equal(r.status, 1);
  assert.match(r.out, /cases\/make\/heredoc\.sh: one command per line/);
});
