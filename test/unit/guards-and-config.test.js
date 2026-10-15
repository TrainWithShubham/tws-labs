const test = require('node:test');
const assert = require('node:assert/strict');
const { guardOk, hostnameOf } = require('../../src/server');
const { loadConfig } = require('../../src/config');

const req = (headers) => ({ headers });
const local = loadConfig({ LAB_PROFILE: 'local' });
const hosted = loadConfig({});

test('profile defaults: hosted unless LAB_PROFILE (or legacy LAB_MODE) says local', () => {
  assert.equal(hosted.profile, 'hosted');
  assert.equal(loadConfig({ LAB_MODE: 'local' }).profile, 'local');
  assert.equal(loadConfig({ EB_MODE: 'cluster' }).profile, 'hosted');
  assert.deepEqual([hosted.maxSessions, hosted.maxPerIp, hosted.idleMs, hosted.hardCapMs], [5, 3, 300000, 900000]);
  assert.deepEqual([local.maxSessions, local.maxPerIp, local.idleMs, local.hardCapMs], [3, 0, 1800000, 7200000]);
  assert.equal(loadConfig({ MAX_CONCURRENT_SESSIONS: '9' }).maxSessions, 9);   // legacy name still honoured
  assert.equal(local.remoteFonts, false);
  assert.equal(hosted.remoteFonts, true);
});

test('local profile: only loopback Host headers pass (DNS-rebinding guard), even for GET', () => {
  for (const h of ['localhost:8080', '127.0.0.1:9000', 'LOCALHOST', '[::1]:8080']) assert.ok(guardOk(req({ host: h }), local, { needOrigin: false }), h);
  for (const h of ['evil.com', 'evil.com:8080', 'localhost.evil.com', '192.168.1.5:8080', undefined]) assert.ok(!guardOk(req({ host: h }), local, { needOrigin: false }), String(h));
  assert.equal(hostnameOf('[::1]:8080'), '[::1]');
});

test('state-changing requests must carry a matching Origin; local = loopback, hosted = same origin', () => {
  const l = (origin) => guardOk(req({ host: 'localhost:8080', origin }), local, { needOrigin: true });
  assert.ok(l('http://localhost:8080'));
  assert.ok(!l(undefined), 'missing Origin rejected for POST/WS');
  assert.ok(!l('https://evil.com'));
  assert.ok(!l('http://localhost.evil.com'));
  assert.ok(!l('null'));
  const h = (origin) => guardOk(req({ host: 'labs.example.com', origin }), hosted, { needOrigin: true });
  assert.ok(h('https://labs.example.com'));
  assert.ok(!h('https://evil.com'));
  assert.ok(!h(undefined));
  assert.ok(guardOk(req({ host: 'anything.example' }), hosted, { needOrigin: false }), 'hosted GET with no Origin is fine');
});

test('LAB_ULIMIT_V_KB overrides the per-profile address-space limit; 0 disables it', () => {
  assert.equal(loadConfig({}).ulimitVKb, 262144);
  assert.equal(loadConfig({ LAB_PROFILE: 'local' }).ulimitVKb, 1048576);
  assert.equal(loadConfig({ LAB_ULIMIT_V_KB: '0' }).ulimitVKb, 0);
  assert.equal(loadConfig({ LAB_ULIMIT_V_KB: '131072' }).ulimitVKb, 131072);
});

test('invite tokens: comma-separated on hosted, never read by the local profile', () => {
  assert.deepEqual(hosted.accessTokens, []);
  assert.deepEqual(loadConfig({ LAB_ACCESS_TOKENS: ' a, b ,,c ' }).accessTokens, ['a', 'b', 'c']);
  assert.deepEqual(loadConfig({ LAB_ACCESS_TOKEN: 'solo' }).accessTokens, ['solo']);
  assert.deepEqual(loadConfig({ LAB_PROFILE: 'local', LAB_ACCESS_TOKENS: 'a' }).accessTokens, []);
});

test('usage counters and the admin page are opt-in: off by default, configured from the environment', () => {
  const off = loadConfig({});
  assert.equal(off.usageStats, false);
  assert.equal(off.usageDir, undefined);
  assert.equal(off.adminToken, '');
  const on = loadConfig({ USAGE_STATS: '1', USAGE_DIR: '/data/usage', USAGE_SALT: 's', USAGE_RETENTION_DAYS: '30', ADMIN_TOKEN: ' adm ' });
  assert.equal(on.usageStats, true);
  assert.equal(on.usageDir, '/data/usage');
  assert.equal(on.usageSalt, 's');
  assert.equal(on.usageRetentionDays, 30);
  assert.equal(on.adminToken, 'adm');
  assert.equal(loadConfig({ USAGE_STATS: '0' }).usageStats, false);
  assert.equal(loadConfig({ USAGE_STATS: '1' }).usageRetentionDays, 90);
});

test('LAB_IDLE_SEC and LAB_HARD_CAP_SEC are seconds-level overrides for tests; the minute settings stay the normal way', () => {
  assert.equal(loadConfig({}).idleMs, 5 * 60 * 1000);
  assert.equal(loadConfig({ LAB_IDLE_MIN: '2' }).idleMs, 2 * 60 * 1000);
  assert.equal(loadConfig({ LAB_IDLE_SEC: '8' }).idleMs, 8000);
  assert.equal(loadConfig({ LAB_IDLE_SEC: '8', LAB_IDLE_MIN: '2' }).idleMs, 8000, 'seconds win');
  assert.equal(loadConfig({ LAB_HARD_CAP_SEC: '30' }).hardCapMs, 30000);
  assert.equal(loadConfig({ LAB_HARD_CAP_SEC: '0' }).hardCapMs, 15 * 60 * 1000, 'zero or junk is ignored');
  assert.equal(loadConfig({ LAB_IDLE_SEC: 'soon' }).idleMs, 5 * 60 * 1000);
});
