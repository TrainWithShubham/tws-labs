// POST /lab/setup: the guards and the answers that need no shell. (The real-shell behaviour is tested in lab-flow.test.js.)
const test = require('node:test');
const assert = require('node:assert/strict');
const { start, post, mint, request } = require('./helpers');
const { skipLabsDir } = require('./aws-labs-fixture');

const setup = (app, body, o) => post(app, '/lab/setup', body, o);

test('guards: cross-origin or origin-less requests, bad JSON, unknown tokens and unknown tasks are refused without side effects', async () => {
  const app = await start({ profile: 'local', labsDir: skipLabsDir() });
  try {
    const { json: { token } } = await mint(app, 's', 'skip');
    assert.equal((await setup(app, { token, stepId: 'use' }, { origin: 'https://evil.com' })).status, 403);
    assert.equal((await setup(app, { token, stepId: 'use' }, { origin: false })).status, 403);
    assert.equal((await setup(app, '{not json')).status, 400);
    assert.equal((await setup(app, { token: 'f'.repeat(32), stepId: 'use' })).status, 403, 'unknown token');
    assert.equal((await setup(app, { token, stepId: 'nope' })).status, 404, 'unknown task');
    assert.equal((await setup(app, { token, stepId: 'intro' })).status, 404, 'a lesson has no setup');
    assert.equal((await setup(app, { token, stepId: 'solo' })).status, 404, 'a task without setup/<task>.sh');
    assert.equal((await setup(app, 'x'.repeat(5000))).status, 413);
  } finally { app.stop(); }
});

test('before the terminal is connected there is nothing to prepare yet, and it says so instead of failing', async () => {
  const app = await start({ profile: 'local', labsDir: skipLabsDir() });
  try {
    const { json: { token } } = await mint(app, 's', 'skip');
    const r = await setup(app, { token, stepId: 'use' });
    assert.equal(r.status, 200);
    assert.equal(r.json.ok, false);
    assert.match(r.json.message, /still connecting/i);
  } finally { app.stop(); }
});

test('the lab page tells the browser which tasks ship setup', async () => {
  const app = await start({ profile: 'local', labsDir: skipLabsDir() });
  try {
    const html = (await request(app, 'GET', '/lab/s/skip')).body;
    const data = JSON.parse(html.match(/<script id="lab-data" type="application\/json">([\s\S]*?)<\/script>/)[1].replace(/\\u003c/g, '<'));
    assert.deepEqual(data.steps.map((s) => [s.id, !!s.setup]), [['intro', false], ['make', false], ['use', true], ['solo', false]]);
    assert.ok(!html.includes('setup/use.sh') && !html.includes('mkdir -p proj'), 'the script itself never reaches the browser');
  } finally { app.stop(); }
});
