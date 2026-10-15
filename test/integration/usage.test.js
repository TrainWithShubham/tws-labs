// The privacy-light usage counters and the token-protected /admin/stats page.
const test = require('node:test');
const assert = require('node:assert/strict');
const { start, get, mint, check, openLab, TEST_TOKEN } = require('./helpers');

const EB = ['aws', 'elastic-beanstalk-cluster-mode'];
const admin = (app, token) => get(app, '/admin/stats', token === undefined ? {} : { headers: { Authorization: `Bearer ${token}` } });
const today = () => new Date().toISOString().slice(0, 10);

test('/admin/stats does not exist unless an admin token is configured', async () => {
  const app = await start();
  try {
    assert.equal((await admin(app)).status, 404);
    assert.equal((await admin(app, '')).status, 404);
    assert.equal((await admin(app, 'anything')).status, 404);
  } finally { app.stop(); }
});

test('/admin/stats needs the bearer token; wrong or missing is 401', async () => {
  const app = await start({ adminToken: 'adm-secret', usageStats: true });
  try {
    assert.equal((await admin(app)).status, 401);
    assert.equal((await admin(app, 'wrong')).status, 401);
    assert.equal((await get(app, '/admin/stats?token=adm-secret')).status, 401, 'a token in the URL is not accepted');
    const ok = await admin(app, 'adm-secret');
    assert.equal(ok.status, 200);
    assert.equal(ok.json.enabled, true);
    assert.equal(ok.headers['cache-control'], 'no-store');
  } finally { app.stop(); }
});

test('with the admin token set but counters off, the page says counting is off', async () => {
  const app = await start({ adminToken: 'adm-secret' });
  try {
    await mint(app, ...EB);
    assert.deepEqual((await admin(app, 'adm-secret')).json, { enabled: false });
  } finally { app.stop(); }
});

test('a minted session is counted per lab, visitor and invite code; nothing identifying is exposed', async () => {
  const app = await start({ adminToken: 'adm-secret', usageStats: true });
  try {
    assert.equal((await mint(app, ...EB)).status, 200);
    assert.equal((await mint(app, ...EB)).status, 200);
    const body = await admin(app, 'adm-secret');
    const day = body.json.days[today()];
    assert.equal(day.sessions, 2);
    assert.equal(day.visitors, 1, 'two sessions from one address are one visitor');
    assert.equal(day.labs['aws/elastic-beanstalk-cluster-mode'].sessions, 2);
    assert.deepEqual(Object.values(day.codes), [2]);
    assert.ok(!body.body.includes('127.0.0.1'), 'no IP address in the page');
    assert.ok(!body.body.includes(TEST_TOKEN), 'no invite code in the page');
  } finally { app.stop(); }
});

test('refused requests are not counted: unknown lab, bad invite code, cross-origin', async () => {
  const app = await start({ adminToken: 'adm-secret', usageStats: true });
  try {
    await mint(app, 'aws', 'nope');
    await mint(app, ...EB, { headers: { 'X-Lab-Token': 'wrong' } });
    await mint(app, ...EB, { origin: 'https://evil.com' });
    assert.deepEqual((await admin(app, 'adm-secret')).json.days, {});
  } finally { app.stop(); }
});

test('the admin page answers on the local profile only for loopback hosts (rebinding guard still applies)', async () => {
  const app = await start({ profile: 'local', adminToken: 'adm-secret', usageStats: true });
  try {
    assert.equal((await get(app, '/admin/stats', { headers: { Authorization: 'Bearer adm-secret' }, host: 'evil.example' })).status, 421);
  } finally { app.stop(); }
});
