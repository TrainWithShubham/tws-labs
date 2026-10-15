// Labs that need the learner's own AWS account: they run on the learner's machine only. (The real-shell test that AWS variables
// reach the shell lives in lab-flow.test.js: only one test file may drive ptys, because concurrent files share the per-session user ids.)
const test = require('node:test');
const assert = require('node:assert/strict');
const { start, get, mint } = require('./helpers');
const { awsLabsDir: labsDir } = require('./aws-labs-fixture');

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
