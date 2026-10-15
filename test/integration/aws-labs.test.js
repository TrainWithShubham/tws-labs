// Labs that need the learner's own AWS account: they run on the learner's machine only, and only then do AWS variables reach the shell.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { start, get, post, mint, check, openLab, sleep, TEST_TOKEN } = require('./helpers');

function canSpawnPty() {
  if (process.platform !== 'linux') return 'needs Linux';
  try { require('node-pty').spawn('/bin/sh', ['-c', 'true'], {}).kill(); return false; } catch { return 'pty cannot spawn here'; }
}
const SKIP = canSpawnPty();

// A one-lab catalog: cloud/acct needs AWS, cloud/plain does not.
function labsDir() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'awslabs-'));
  fs.chmodSync(root, 0o755);   // in the image each session runs as its own user, which must be able to read the checks
  fs.copyFileSync(path.join(__dirname, '..', '..', 'labs', 'lib.sh'), path.join(root, 'lib.sh'));
  fs.mkdirSync(path.join(root, 'cloud'));
  fs.writeFileSync(path.join(root, 'cloud', 'track.yaml'), 'title: Cloud\ndescription: d\nlabs: [acct, plain]\n');
  for (const [id, requires] of [['acct', 'requires: aws\n'], ['plain', '']]) {
    const d = path.join(root, 'cloud', id);
    fs.mkdirSync(path.join(d, 'checks'), { recursive: true });
    fs.mkdirSync(path.join(d, 'solutions'), { recursive: true });
    fs.writeFileSync(path.join(d, 'lab.yaml'), `${requires}title: ${id}\nlevel: beginner\nminutes: 10\nsummary: s\nsteps:\n  - {id: intro, type: lesson, title: Intro, body: "Use **your own** account."}\n  - {id: show, type: task, title: Show it, body: do it, hint: "a nudge here"}\n`);
    fs.writeFileSync(path.join(d, 'checks', 'show.sh'), '. "$LAB_LIB"\n[ "$AWS_REGION" = "us-east-1" ] || fail "no region"\n');
    fs.writeFileSync(path.join(d, 'solutions', 'show.sh'), 'true\n');
  }
  return root;
}

test('hosted: a session for an account lab is refused with a pointer to running it locally; other labs are unaffected', async () => {
  const app = await start({ profile: 'hosted', labsDir: labsDir() });
  try {
    const refused = await mint(app, 'cloud', 'acct');
    assert.equal(refused.status, 403);
    assert.equal(refused.json.error, 'needs-local');
    assert.match(refused.json.message, /your own AWS account/);
    assert.equal(app.store.size(), 0, 'a refused request never takes a seat');
    assert.equal((await mint(app, 'cloud', 'plain')).status, 200);
  } finally { app.stop(); }
});

test('hosted: the lab page of an account lab is a read-only walkthrough with no terminal, and says how to run it locally', async () => {
  const app = await start({ profile: 'hosted', labsDir: labsDir() });
  try {
    const page = (await get(app, '/lab/cloud/acct')).body;
    assert.match(page, /runs on your machine/);
    assert.match(page, /AWS=1 \.\/start_local_labs\.sh/);
    assert.match(page, /Use <strong>your own<\/strong> account/, 'the steps can still be read');
    assert.ok(!page.includes('id="term"'), 'no terminal');
    assert.ok(!page.includes('/lab.js'), 'no terminal script');
    const plain = (await get(app, '/lab/cloud/plain')).body;
    assert.ok(plain.includes('id="term"'), 'a normal lab still has its terminal');
  } finally { app.stop(); }
});

test('local: an account lab opens like any other lab', async () => {
  const app = await start({ profile: 'local', labsDir: labsDir() });
  try {
    assert.equal((await mint(app, 'cloud', 'acct')).status, 200);
    assert.ok((await get(app, '/lab/cloud/acct')).body.includes('id="term"'));
  } finally { app.stop(); }
});

test('local, in a real shell: AWS variables reach an account lab and its checks, other labs and other secrets never', { skip: SKIP }, async () => {
  const saved = { ...process.env };
  Object.assign(process.env, { AWS_REGION: 'us-east-1', AWS_ACCESS_KEY_ID: 'AKIAEXAMPLE', AWS_SECRET_ACCESS_KEY: 'shh', ADMIN_TOKEN: 'adm-secret' });
  const app = await start({ profile: 'local', labsDir: labsDir() });
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
