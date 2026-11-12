// Labs that run against the AWS Emulator sidecar (`requires: emulator`): local only, and only when the compose overlay is on.
// (The real-shell test that the emulator environment reaches the shell lives in lab-flow.test.js: only one test file may drive ptys.)
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { start, get, mint } = require('./helpers');

function emulatorLabsDir() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'emulabs-'));
  fs.chmodSync(root, 0o755);
  fs.copyFileSync(path.join(__dirname, '..', '..', 'labs', 'lib.sh'), path.join(root, 'lib.sh'));
  fs.mkdirSync(path.join(root, 'cloud'));
  fs.writeFileSync(path.join(root, 'cloud', 'track.yaml'), 'title: Cloud\ndescription: d\nlabs: [emu, plain, acct]\n');
  for (const [id, requires] of [['emu', 'requires: emulator\n'], ['plain', ''], ['acct', 'requires: aws\n']]) {
    const d = path.join(root, 'cloud', id);
    fs.mkdirSync(path.join(d, 'checks'), { recursive: true });
    fs.mkdirSync(path.join(d, 'solutions'), { recursive: true });
    fs.writeFileSync(path.join(d, 'lab.yaml'), `${requires}title: ${id}\nlevel: beginner\nminutes: 10\nsummary: s\nsteps:\n  - {id: intro, type: lesson, title: Intro, body: "Practise against the **emulator**."}\n  - {id: show, type: task, title: Show, body: b}\n`);
    fs.writeFileSync(path.join(d, 'checks', 'show.sh'), '. "$LAB_LIB"\ntrue\n');
    fs.writeFileSync(path.join(d, 'solutions', 'show.sh'), 'true\n');
  }
  return root;
}
const WITH_EMULATOR = { endpoint: 'https://127.0.0.1:9297', caSource: '/nonexistent/ca.pem', caFile: path.join(os.tmpdir(), 'tws-test-ca.pem') };
const NO_EMULATOR = { endpoint: '', caSource: '', caFile: path.join(os.tmpdir(), 'tws-test-ca.pem') };

test('hosted: a session for an emulator lab is refused with a pointer to running it locally; other labs are unaffected', async () => {
  const app = await start({ profile: 'hosted', labsDir: emulatorLabsDir() });
  try {
    const refused = await mint(app, 'cloud', 'emu');
    assert.equal(refused.status, 403);
    assert.equal(refused.json.error, 'needs-local');
    assert.match(refused.json.message, /AWS Emulator/);
    assert.equal(app.store.size(), 0, 'a refused request never takes a seat');
    assert.equal((await mint(app, 'cloud', 'plain')).status, 200);
  } finally { app.stop(); }
});

test('hosted: the page of an emulator lab is a read-only walkthrough that needs no account and says how to start the emulator', async () => {
  const app = await start({ profile: 'hosted', labsDir: emulatorLabsDir() });
  try {
    const page = (await get(app, '/lab/cloud/emu')).body;
    assert.match(page, /You do not need an AWS account/);
    assert.match(page, /EMULATOR=1 \.\/start_local_labs\.sh/);
    assert.ok(!page.includes('AWS=1 ./start_local_labs.sh'), 'it is not the account-lab banner');
    assert.match(page, /Practise against the <strong>emulator<\/strong>/, 'the steps can still be read');
    assert.ok(!page.includes('id="term"') && !page.includes('/lab.js'), 'no terminal');
  } finally { app.stop(); }
});

test('local without the emulator: the session answers needs-emulator and says how to start it, and takes no seat', async () => {
  const app = await start({ profile: 'local', labsDir: emulatorLabsDir(), emulator: NO_EMULATOR });
  try {
    const r = await mint(app, 'cloud', 'emu');
    assert.equal(r.status, 409);
    assert.equal(r.json.error, 'needs-emulator');
    assert.match(r.json.message, /EMULATOR=1 \.\/start_local_labs\.sh/);
    assert.equal(app.store.size(), 0);
    assert.equal((await mint(app, 'cloud', 'plain')).status, 200, 'other labs do not care');
  } finally { app.stop(); }
});

test('local with the emulator: the lab opens like any other, and its page tells the browser to wait for the emulator', async () => {
  const app = await start({ profile: 'local', labsDir: emulatorLabsDir(), emulator: WITH_EMULATOR });
  try {
    assert.equal((await mint(app, 'cloud', 'emu')).status, 200);
    const page = (await get(app, '/lab/cloud/emu')).body;
    assert.ok(page.includes('id="term"'));
    assert.match(page, /"emulator":true/);
    assert.match((await get(app, '/lab/cloud/plain')).body, /"emulator":false/);
  } finally { app.stop(); }
});

test('the emulator status route says whether the sidecar is configured and answering, and is quiet when it is not', async () => {
  const off = await start({ profile: 'local', labsDir: emulatorLabsDir(), emulator: NO_EMULATOR });
  try {
    const r = await get(off, '/emulator/status');
    assert.equal(r.status, 200);
    assert.deepEqual(r.json, { configured: false, ready: false });
  } finally { off.stop(); }
  const starting = await start({ profile: 'local', labsDir: emulatorLabsDir(), emulator: WITH_EMULATOR });
  try {
    assert.deepEqual((await get(starting, '/emulator/status')).json, { configured: true, ready: false }, 'configured, but no certificate or server yet');
  } finally { starting.stop(); }
});

test('the emulator status route sits behind the same DNS-rebinding guard as every route: a foreign Host is refused', async () => {
  const app = await start({ profile: 'local', labsDir: emulatorLabsDir(), emulator: WITH_EMULATOR });
  try {
    const r = await get(app, '/emulator/status', { host: 'evil.example' });
    assert.equal(r.status, 421);
  } finally { app.stop(); }
});

test('the track page tells a learner which labs need no account and which need their own, and says nothing about plain labs', async () => {
  const app = await start({ profile: 'local', labsDir: emulatorLabsDir(), emulator: WITH_EMULATOR });
  try {
    const page = (await get(app, '/t/cloud')).body;
    const row = (id) => page.split('<li data-status="live">').find((x) => x.includes(`/lab/cloud/${id}"`)) || '';
    assert.match(row('emu'), /<span class="tag"[^>]*>AWS Emulator<\/span>/);
    assert.match(row('acct'), /<span class="tag"[^>]*>Your AWS account<\/span>/);
    assert.ok(!/class="tag"/.test(row('plain')), 'a plain lab carries no tag');
  } finally { app.stop(); }
});

test('the lab page says on the terminal tab that its commands run against the emulator, and only for emulator labs', async () => {
  const app = await start({ profile: 'local', labsDir: emulatorLabsDir(), emulator: WITH_EMULATOR });
  try {
    const emu = (await get(app, '/lab/cloud/emu')).body;
    assert.match(emu, /class="term-note"[^>]*>&middot; AWS Emulator<\/span>/);
    assert.ok(!(await get(app, '/lab/cloud/plain')).body.includes('term-note'));
    assert.ok(!(await get(app, '/lab/cloud/acct')).body.includes('term-note'), 'an account lab talks to real AWS');
  } finally { app.stop(); }
});
