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

// --- skipping ahead: a task must be solvable without the tasks before it, using its setup/<task>.sh if it ships one ---
function chained(extra = {}) {
  const root = lab({});
  const d = path.join(root, 't', 'one');
  fs.writeFileSync(path.join(d, 'lab.yaml'), 'title: One\nlevel: beginner\nminutes: 10\nsummary: s\nsteps:\n  - {id: intro, type: lesson, title: Intro, body: hi}\n  - {id: make, type: task, title: Make, body: "Create hello.txt containing hello.", hint: "A nudge that is long enough", success: Done}\n  - {id: shout, type: task, title: Shout, body: "Make HELLO in upper case in loud.txt.", hint: "Another nudge long enough", success: Done}\n');
  fs.writeFileSync(path.join(d, 'checks', 'shout.sh'), '. "$LAB_LIB"\n[ "$(cat loud.txt 2>/dev/null)" = "HELLO" ] || fail "loud.txt should say HELLO."\n');
  fs.writeFileSync(path.join(d, 'solutions', 'shout.sh'), "tr a-z A-Z < hello.txt > loud.txt\n");   // needs hello.txt from the task before
  for (const [name, text] of Object.entries(extra)) { fs.mkdirSync(path.join(d, 'setup'), { recursive: true }); fs.writeFileSync(path.join(d, 'setup', `${name}.sh`), text); }
  return root;
}

test('a task that needs the one before it fails validation until it ships a setup', { skip: SKIP }, () => {
  const r = validate(chained());
  assert.equal(r.status, 1);
  assert.match(r.out, /skip-ahead shout: a learner who skips to this task is stuck/);
  assert.match(r.out, /Add setup\/shout\.sh/);
});

test('with setup/<task>.sh the skipped-to task is solvable, and the setup is safe to run on top of earlier work', { skip: SKIP }, () => {
  const r = validate(chained({ shout: '#!/bin/bash\n[ -s hello.txt ] || echo hello > hello.txt\n' }));
  assert.equal(r.status, 0, r.out);
  assert.match(r.out, /ok\s+skip-ahead shout \(with setup\)/);
});

test('"# no-skip: reason" says a task genuinely builds on the one before, and is exempt', { skip: SKIP }, () => {
  const r = validate(chained({ shout: '# no-skip: it uppercases the file you made in the step before\n' }));
  assert.equal(r.status, 0, r.out);
});

test('a setup that fails, or that names a folder it does not create, fails validation with the reason', { skip: SKIP }, () => {
  assert.match(validate(chained({ shout: '#!/bin/bash\nexit 3\n' })).out, /skip-ahead shout: setup\/shout\.sh failed/);
  assert.match(validate(chained({ shout: '#!/bin/bash\n# cwd: nowhere\necho hello > hello.txt\n' })).out, /says "# cwd: nowhere" but that folder does not exist/);
});
