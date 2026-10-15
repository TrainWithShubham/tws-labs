const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const { createUsage, codeId } = require('../../src/usage');

const DAY = 24 * 3600 * 1000;
const T0 = Date.UTC(2026, 9, 14, 12, 0, 0);          // 2026-10-14
const tmp = () => fs.mkdtempSync(path.join(os.tmpdir(), 'usage-'));
const make = (opts = {}) => {
  const clock = { now: T0 };
  const lines = [];
  const usage = createUsage({ enabled: true, secret: 's3cret', now: () => clock.now, log: (l) => lines.push(l), ...opts });
  return { usage, clock, lines };
};

test('disabled by default: nothing is recorded and the summary says so', () => {
  const lines = [];
  const usage = createUsage({ log: (l) => lines.push(l) });
  usage.session({ track: 'linux-fundamentals', lab: 'files', ip: '1.2.3.4', token: 'x' });
  assert.deepEqual(usage.summary(), { enabled: false });
  assert.deepEqual(lines, []);
});

test('sessions are counted per lab and day, and one visitor counts once per day', () => {
  const { usage, clock } = make();
  usage.session({ track: 'git-basics', lab: 'gitignore', ip: '1.1.1.1' });
  usage.session({ track: 'git-basics', lab: 'gitignore', ip: '1.1.1.1' });
  usage.session({ track: 'git-basics', lab: 'gitignore', ip: '2.2.2.2' });
  usage.session({ track: 'docker', lab: 'dockerfile-craft', ip: '1.1.1.1' });
  const day = usage.summary().days['2026-10-14'];
  assert.equal(day.sessions, 4);
  assert.equal(day.visitors, 2);
  assert.equal(day.labs['git-basics/gitignore'].sessions, 3);
  assert.equal(day.labs['docker/dockerfile-craft'].sessions, 1);
  clock.now += DAY;
  usage.session({ track: 'git-basics', lab: 'gitignore', ip: '1.1.1.1' });
  assert.equal(usage.summary().days['2026-10-15'].visitors, 1, 'the same address is a new visitor on a new day');
});

test('the visitor id rotates daily, so it cannot follow someone across days', () => {
  const { usage, clock, lines } = make();
  usage.session({ track: 't', lab: 'l', ip: '9.9.9.9' });
  clock.now += DAY;
  usage.session({ track: 't', lab: 'l', ip: '9.9.9.9' });
  const [a, b] = lines.map((l) => JSON.parse(l).v);
  assert.match(a, /^[0-9a-f]{12}$/);
  assert.notEqual(a, b);
});

test('check results are counted per task as pass or fail', () => {
  const { usage } = make();
  const c = (pass) => usage.check({ track: 'git-basics', lab: 'gitignore', step: 'create-rules', pass, ip: '1.1.1.1' });
  c(false); c(false); c(true);
  const lab = usage.summary().days['2026-10-14'].labs['git-basics/gitignore'];
  assert.deepEqual(lab.checks, { pass: 1, fail: 2 });
  assert.deepEqual(lab.tasks['create-rules'], { pass: 1, fail: 2 });
});

test('the invite code is recorded only as a short hash, and sessions are counted per code', () => {
  const { usage, lines } = make();
  usage.session({ track: 't', lab: 'l', ip: '1.1.1.1', token: 'invite-for-the-video' });
  usage.session({ track: 't', lab: 'l', ip: '1.1.1.2', token: 'invite-for-the-video' });
  usage.session({ track: 't', lab: 'l', ip: '1.1.1.3' });
  const id = crypto.createHash('sha256').update('invite-for-the-video').digest('hex').slice(0, 8);
  assert.equal(codeId('invite-for-the-video'), id);
  assert.equal(usage.summary().days['2026-10-14'].codes[id], 2);
  assert.ok(!lines.join('\n').includes('invite-for-the-video'));
});

test('no raw IP address or invite code ever reaches the log or the file', () => {
  const dir = tmp();
  const { usage, lines } = make({ dir });
  usage.session({ track: 't', lab: 'l', ip: '203.0.113.77', token: 'tok-abcdefghijklmnop' });
  usage.check({ track: 't', lab: 'l', step: 's', pass: true, ip: '203.0.113.77', token: 'tok-abcdefghijklmnop' });
  const all = lines.join('\n') + fs.readFileSync(path.join(dir, 'usage.jsonl'), 'utf8');
  assert.ok(!all.includes('203.0.113.77'));
  assert.ok(!all.includes('tok-abcdefghijklmnop'));
});

test('with a directory the counts survive a restart, and old days and bad lines are dropped', () => {
  const dir = tmp();
  const first = make({ dir, retentionDays: 30 });
  first.usage.session({ track: 't', lab: 'l', ip: '1.1.1.1' });
  first.clock.now -= 40 * DAY;
  first.usage.session({ track: 't', lab: 'old', ip: '1.1.1.1' });
  fs.appendFileSync(path.join(dir, 'usage.jsonl'), 'not json\n{"ev":"nope"}\n');
  const second = make({ dir, retentionDays: 30 });
  const days = second.usage.summary().days;
  assert.deepEqual(Object.keys(days), ['2026-10-14']);
  assert.equal(days['2026-10-14'].labs['t/l'].sessions, 1);
  const kept = fs.readFileSync(path.join(dir, 'usage.jsonl'), 'utf8').trim().split('\n');
  assert.equal(kept.length, 1, 'the file is pruned on start');
});

test('an unwritable directory never breaks recording', () => {
  const blocker = path.join(tmp(), 'a-file');
  fs.writeFileSync(blocker, 'x');                         // a directory cannot be created underneath a regular file
  const { usage } = make({ dir: path.join(blocker, 'usage') });
  usage.session({ track: 't', lab: 'l', ip: '1.1.1.1' });
  assert.equal(usage.summary().days['2026-10-14'].sessions, 1);
});

test('the summary ranks the hardest tasks: lowest pass rate first, only with enough attempts', () => {
  const { usage, clock } = make();
  const run = (lab, step, results) => results.forEach((pass) => usage.check({ track: 't', lab, step, pass, ip: '1.1.1.1' }));
  run('l', 'easy', [true, true, true, true, true, false]);          // 5/6
  run('l', 'hard', [false, false, false, true, false, false]);      // 1/6
  run('l', 'rare', [false, false]);                                 // too few attempts to judge
  clock.now += DAY;                                                 // counted across days
  run('m', 'middling', [true, false, true, false, true, false]);    // 3/6
  run('l', 'hard', [false]);                                        // now 1/7
  const h = usage.summary().hardestTasks;
  assert.deepEqual(h.map((x) => `${x.lab}/${x.step}`), ['t/l/hard', 't/m/middling', 't/l/easy']);
  assert.deepEqual({ ...h[0] }, { lab: 't/l', step: 'hard', attempts: 7, passes: 1, passRate: 0.14 });
  assert.ok(!h.some((x) => x.step === 'rare'));
});

test('the hardest list is capped at ten and is empty when nothing was graded', () => {
  const { usage } = make();
  assert.deepEqual(usage.summary().hardestTasks, []);
  for (let i = 0; i < 12; i++) for (let k = 0; k < 5; k++) usage.check({ track: 't', lab: 'l', step: `s${i}`, pass: k === 0, ip: '1.1.1.1' });
  assert.equal(usage.summary().hardestTasks.length, 10);
});
