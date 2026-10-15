// Real shells over real WebSockets, graded by the real check scripts. Needs Linux
// (/proc, `ps -s`, a working pty). Elsewhere these skip with a reason instead of failing;
// run them in the image: docker compose run --rm labs sh -c 'node --test test/integration/*.test.js'
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { start, check, openLab, sleep, ISOLATED, WebSocket } = require('./helpers');
const { awsLabsDir } = require('./aws-labs-fixture');
const { loadCatalog } = require('../../src/loader');

function canSpawnPty() {
  if (process.platform !== 'linux') return 'needs Linux';
  try { require('node-pty').spawn('/bin/sh', ['-c', 'true'], {}).kill(); return false; } catch { return 'pty cannot spawn here'; }
}
const SKIP = canSpawnPty();
const t = (name, fn) => test(name, { skip: SKIP }, fn);
const iso = (name, fn) => test(name, { skip: SKIP || (!ISOLATED && 'needs root + LAB_UID (the image)') }, fn);
const pass = async (app, token, step) => (await check(app, token, step)).json.pass;
const EB = ['aws', 'elastic-beanstalk-cluster-mode'];

t('files lab: graded on real state, typed one keystroke at a time; failure messages nudge without giving the answer', async () => {
  const app = await start();
  const lab = await openLab(app, 'linux-fundamentals', 'files');
  try {
    assert.equal(await pass(app, lab.token, 'mkdir'), false);
    await lab.run('mkdir workspace');
    assert.equal(await pass(app, lab.token, 'mkdir'), true);
    await lab.run('echo "hello linux" > workspace/hello.txt');
    assert.equal(await pass(app, lab.token, 'write'), true);
    const wrong = (await check(app, lab.token, 'cp')).json;
    assert.equal(wrong.pass, false);
    assert.match(wrong.message, /backup/);
  } finally { lab.ws.close(); app.stop(); }
});

t('shell scripting lab: a script typed into the live terminal is executable in the sandbox and graded by running it', async () => {
  const app = await start();
  const lab = await openLab(app, 'linux-fundamentals', 'shell-scripting-basics');
  try {
    assert.equal(await pass(app, lab.token, 'hello'), false);
    await lab.run("printf '#!/bin/bash\\necho \"Hello, World!\"\\n' > hello.sh");
    const early = (await check(app, lab.token, 'hello')).json;
    assert.equal(early.pass, false);
    assert.match(early.message, /executable/);
    await lab.run('chmod +x hello.sh');
    assert.match(await lab.run('./hello.sh'), /Hello, World!/);
    assert.equal(await pass(app, lab.token, 'hello'), true);
    await lab.run("printf '#!/bin/bash\\necho \"Hello, $1!\"\\n' > greet.sh");
    assert.equal(await pass(app, lab.token, 'arguments'), true, 'greet.sh is run with several different arguments');
  } finally { lab.ws.close(); app.stop(); }
});

t('shell cwd is graded live, and bare `cd` returns to the session home', async () => {
  const app = await start();
  const lab = await openLab(app, 'linux-fundamentals', 'navigating');
  try {
    assert.equal(await pass(app, lab.token, 'cd-down'), false);
    await lab.run('cd projects/website');
    assert.equal(await pass(app, lab.token, 'cd-down'), true);
    assert.equal(await pass(app, lab.token, 'cd-home'), false);
    await lab.run('cd');
    assert.equal(await pass(app, lab.token, 'cd-home'), true);
  } finally { lab.ws.close(); app.stop(); }
});

t('git lab: setup seeds a repo with an identity, and git state is what is graded', async () => {
  const app = await start();
  const lab = await openLab(app, 'git-basics', 'branches-and-merge');
  try {
    await lab.run('cd proj');
    await lab.run('git switch -c feature');
    assert.equal(await pass(app, lab.token, 'enter'), true);
    assert.equal(await pass(app, lab.token, 'new-branch'), true);
    assert.equal(await pass(app, lab.token, 'commit-on-branch'), false);
    await lab.run('echo hi > feature.txt && git add feature.txt && git commit -q -m "Add feature"');
    assert.equal(await pass(app, lab.token, 'commit-on-branch'), true);
  } finally { lab.ws.close(); app.stop(); }
});

t('EB lab: hostname needs the command actually run (typing or echoing the word is not enough)', async () => {
  const app = await start();
  const lab = await openLab(app, ...EB);
  try {
    await lab.run('echo hostname');
    assert.equal(await pass(app, lab.token, 'hostname'), false);
    await lab.run('hostname');
    assert.equal(await pass(app, lab.token, 'hostname'), true);
  } finally { lab.ws.close(); app.stop(); }
});

t('EB lab: container-vs-node and limits pass only after the real commands are submitted', async () => {
  const app = await start();
  const lab = await openLab(app, ...EB);
  try {
    assert.equal(await pass(app, lab.token, 'container-vs-node'), false);
    await lab.run('cat /etc/os-release');
    assert.equal(await pass(app, lab.token, 'container-vs-node'), false, 'uname still missing');
    await lab.run('uname -r');
    assert.equal(await pass(app, lab.token, 'container-vs-node'), true);
    await lab.run('cat /sys/fs/cgroup/memory.max');
    assert.equal(await pass(app, lab.token, 'limits'), false);
    await lab.run('cat /sys/fs/cgroup/cpu.max');
    assert.equal(await pass(app, lab.token, 'limits'), true);
  } finally { lab.ws.close(); app.stop(); }
});

t('EB lab: mark is per-session; scale passes while yes runs; cleanup needs it started AND killed', async () => {
  const app = await start();
  const a = await openLab(app, ...EB);
  const b = await openLab(app, ...EB);
  try {
    assert.equal(await pass(app, a.token, 'mark'), false);
    await a.run('echo "Jack" > ~/mark.txt');
    assert.equal(await pass(app, a.token, 'mark'), true);
    assert.equal(await pass(app, b.token, 'mark'), false, "another session's mark must not satisfy this one");

    assert.equal(await pass(app, a.token, 'cleanup'), false, 'skipping ahead must not pass vacuously');
    assert.equal(await pass(app, a.token, 'scale'), false);
    await a.run('yes > /dev/null &');
    assert.equal(await pass(app, a.token, 'scale'), true);
    assert.equal(await pass(app, b.token, 'scale'), false, "b is not running yes: a's process must not count");
    assert.equal(await pass(app, a.token, 'cleanup'), false, 'yes is still running');
    await a.run('kill %1');
    await sleep(200);
    assert.equal(await pass(app, a.token, 'cleanup'), true);
  } finally { a.ws.close(); b.ws.close(); app.stop(); }
});

t('a background process is reaped when its session disconnects without an explicit kill', async () => {
  const app = await start();
  const lab = await openLab(app, ...EB);
  try {
    const out = await lab.run('sleep 300 & echo PID=$!');
    const pid = parseInt(out.match(/PID=(\d+)/)[1], 10);
    process.kill(pid, 0);                                  // alive
    lab.ws.close();
    await sleep(800);
    assert.throws(() => process.kill(pid, 0), { code: 'ESRCH' });
  } finally { app.stop(); }
});

t('a second WebSocket on one token is refused; `exit` ends the session; the sandbox home is deleted', async () => {
  const app = await start();
  const lab = await openLab(app, 'linux-fundamentals', 'files');
  try {
    const code = await new Promise((resolve) => {
      const dup = new WebSocket(`ws://127.0.0.1:${app.port}/ws?token=${lab.token}`, { headers: { Origin: app.origin } });
      dup.on('close', (c) => resolve(c));
    });
    assert.equal(code, 4002);
    const home = path.join(app.sandboxDir, lab.id);
    assert.ok(fs.existsSync(home));
    const closed = new Promise((resolve) => lab.ws.on('close', (c, r) => resolve(r.toString())));
    await lab.type('exit\r');
    assert.equal(await closed, 'shell exited');
    await sleep(500);
    assert.ok(!fs.existsSync(home), 'home removed when the session ends');
    assert.equal(app.store.size(), 0, 'the seat is freed');
  } finally { app.stop(); }
});

t('a resize control frame resizes the pty and is never typed into the shell; an oversized frame drops only that client', async () => {
  const app = await start();
  const lab = await openLab(app, 'linux-fundamentals', 'files');
  const other = await openLab(app, 'linux-fundamentals', 'files');
  try {
    lab.ws.send('\u0000resize:132,41');
    await sleep(200);
    assert.match(await lab.run('stty size'), /41 132/);
    assert.ok(!lab.output().includes('resize:'));
    const closed = new Promise((resolve) => lab.ws.on('close', resolve));
    lab.ws.send('x'.repeat(70 * 1024));
    await closed;
    assert.match(await other.run('echo still-alive'), /still-alive/, 'other sessions are unaffected');
  } finally { other.ws.close(); app.stop(); }
});

iso('isolation: every session is its own unprivileged user; one learner cannot read or signal another', async () => {
  const app = await start();
  const a = await openLab(app, ...EB);
  const b = await openLab(app, ...EB);
  try {
    const uidOf = async (l) => (await l.run('id -u')).match(/(\d{4,})\r?\n/)[1];
    const [ua, ub] = [await uidOf(a), await uidOf(b)];
    assert.notEqual(ua, ub);
    assert.ok(Number(ua) >= 10000 && Number(ub) >= 10000, 'never root');

    await a.run('echo secret > ~/s.txt');
    const read = await b.run(`cat ${path.join(app.sandboxDir, a.id)}/s.txt`);
    assert.match(read, /Permission denied/);
    assert.ok(!read.includes('secret\r'), 'content did not leak');
    assert.match(await b.run(`ls ${app.sandboxDir}`), /Permission denied/, 'sandbox root cannot be listed');

    await a.run('yes > /dev/null &');
    await b.run('pkill -x yes');                           // different uid: the signal is refused
    assert.equal(await pass(app, a.token, 'scale'), true, "b could not kill a's process");
  } finally { a.ws.close(); b.ws.close(); app.stop(); }
});

t('resource limits are really applied inside the shell (processes, address space, file size) - hosted and local differ', async () => {
  for (const [profile, vKb] of [['hosted', 262144], ['local', 1048576]]) {
    const app = await start({ profile });
    const lab = await openLab(app, 'linux-fundamentals', 'files');
    try {
      const out = await lab.run('echo LIM u=$(ulimit -u) v=$(ulimit -v) f=$(ulimit -f)');
      assert.match(out, new RegExp(`LIM u=256 v=${vKb} f=40960`), profile);
    } finally { lab.ws.close(); app.stop(); }
  }
});

t('memory pressure sacrifices learner processes first: every shell (and its children) has the maximum OOM score', async () => {
  const app = await start();
  const lab = await openLab(app, 'linux-fundamentals', 'files');
  try {
    assert.match(await lab.run('cat /proc/self/oom_score_adj'), /(^|\D)1000\r?\n/);
    assert.match(await lab.run('sh -c "cat /proc/self/oom_score_adj"'), /(^|\D)1000\r?\n/, 'inherited by children');
  } finally { lab.ws.close(); app.stop(); }
});

iso('isolation: learners cannot read the lab answers (solutions/) but the checks still work', async () => {
  const app = await start();
  const lab = await openLab(app, 'linux-fundamentals', 'files');
  try {
    const out = await lab.run(`cat ${path.join(app.cfg.labsDir, 'linux-fundamentals', 'files', 'solutions', 'mkdir.sh')}`);
    assert.match(out, /Permission denied/);
    await lab.run('mkdir workspace');
    assert.equal(await pass(app, lab.token, 'mkdir'), true);
  } finally { lab.ws.close(); app.stop(); }
});

t('usage counters see real check results per task: a failed Check and then a pass are counted separately', async () => {
  const app = await start({ usageStats: true, adminToken: 'adm' });
  const lab = await openLab(app, 'linux-fundamentals', 'files');
  try {
    assert.equal(await pass(app, lab.token, 'mkdir'), false);
    await lab.run('mkdir workspace');
    assert.equal(await pass(app, lab.token, 'mkdir'), true);
    const { json } = await require('./helpers').get(app, '/admin/stats', { headers: { Authorization: 'Bearer adm' } });
    const l = Object.values(json.days)[0].labs['linux-fundamentals/files'];
    assert.deepEqual(l.tasks.mkdir, { pass: 1, fail: 1 });
    assert.deepEqual(l.checks, { pass: 1, fail: 1 });
  } finally { lab.ws.close(); app.stop(); }
});

t('restarting a lab (close the terminal, start a new session) gives fresh files and a clean command history', async () => {
  const app = await start();
  const first = await openLab(app, 'linux-fundamentals', 'files');
  let second;
  try {
    await first.run('mkdir workspace');
    assert.equal(await pass(app, first.token, 'mkdir'), true);
    first.ws.close(1000, 'restarted by learner');
    for (let i = 0; i < 50 && app.store.size() > 0; i++) await sleep(40);   // the server frees the seat and the sandbox on close
    assert.equal(app.store.size(), 0, 'the old session is gone');
    second = await openLab(app, 'linux-fundamentals', 'files');
    assert.equal(await pass(app, second.token, 'mkdir'), false, 'the new sandbox has no workspace folder');
    await second.run('mkdir workspace');
    assert.equal(await pass(app, second.token, 'mkdir'), true);
  } finally { first.ws.close(); if (second) second.ws.close(); app.stop(); }
});

t('local, in a real shell: AWS variables reach an account lab and its checks, other labs and other secrets never', async () => {
  const saved = { ...process.env };
  Object.assign(process.env, { AWS_REGION: 'us-east-1', AWS_ACCESS_KEY_ID: 'AKIAEXAMPLE', AWS_SECRET_ACCESS_KEY: 'shh', ADMIN_TOKEN: 'adm-secret' });
  const app = await start({ profile: 'local', labsDir: awsLabsDir() });
  try {
    const acct = await openLab(app, 'cloud', 'acct');
    try {
      const out = await acct.run('echo "[$AWS_ACCESS_KEY_ID][$AWS_REGION][$ADMIN_TOKEN]"');
      assert.match(out, /\[AKIAEXAMPLE\]\[us-east-1\]\[\]/);
      assert.equal((await check(app, acct.token, 'show')).json.pass, true, 'checks see the variables too');
    } finally { acct.ws.close(); }
    const plain = await openLab(app, 'cloud', 'plain');
    try {
      const out = await plain.run('echo "[$AWS_ACCESS_KEY_ID][$AWS_REGION]"');
      assert.match(out, /\[\]\[\]/);
      assert.equal((await check(app, plain.token, 'show')).json.pass, false, 'a plain lab\'s checks do not see them');
    } finally { plain.ws.close(); }
  } finally {
    for (const k of ['AWS_REGION', 'AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'ADMIN_TOKEN']) { if (saved[k] === undefined) delete process.env[k]; else process.env[k] = saved[k]; }
    app.stop();
  }
});

// The playthrough: every offline lab, every task, through the path a learner uses (a real WebSocket shell, the line tracker that feeds
// `ran` checks, and POST /lab/check), not the validator's own shell. Account labs need a real AWS account and have their own tests.
const solutionLines = (file) => fs.readFileSync(file, 'utf8').split('\n').map((l) => l.trim()).filter((l) => l && !l.startsWith('#'));
for (const track of loadCatalog(path.join(__dirname, '..', '..', 'labs')).tracks) {
  for (const lab of track.labs) {
    if (lab.requires) continue;
    test(`playthrough ${track.id}/${lab.id}: each task fails before its solution and passes after it, as a learner would run it`, { skip: SKIP, timeout: 180000 }, async () => {
      const app = await start();
      const session = await openLab(app, track.id, lab.id);
      try {
        for (const step of lab.steps.filter((x) => x.type === 'task')) {
          assert.equal(await pass(app, session.token, step.id), false, `${step.id} must fail before its solution`);
          for (const line of solutionLines(step.solutionFile)) await session.run(line);
          const after = await check(app, session.token, step.id);
          assert.equal(after.json.pass, true, `${step.id} must pass after its solution (the learner would see: "${after.json.message || ''}")`);
        }
      } finally { session.ws.close(); app.stop(); }
    });
  }
}

t('skipping ahead: the task\'s setup is run in the learner\'s own sandbox, moves their shell to the right folder, and is safe to repeat', async () => {
  const { skipLabsDir } = require('./aws-labs-fixture');
  const app = await start({ profile: 'local', labsDir: skipLabsDir() });
  const lab = await openLab(app, 's', 'skip');
  try {
    const post = (stepId) => require('./helpers').post(app, '/lab/setup', { token: lab.token, stepId });
    assert.equal(await pass(app, lab.token, 'use'), false, 'before: proj/data.txt is not there');
    const r = await post('use');
    assert.deepEqual([r.status, r.json.ok], [200, true]);
    await lab.waitFor(/~\/proj/, 8000);                                  // the shell was moved into proj
    const ls = await lab.run('ls -d ~/proj && pwd');
    assert.match(ls, /\/proj\r?\n.*\/proj/s, 'proj exists and the shell is inside it');
    assert.equal((await post('use')).json.ok, true, 'running it twice is fine');
    await lab.run('echo x > data.txt');                                  // the learner now solves the task from where setup put them
    assert.equal(await pass(app, lab.token, 'use'), true);
  } finally { lab.ws.close(); app.stop(); }
});
