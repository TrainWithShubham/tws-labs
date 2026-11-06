const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');
const http = require('http');
const { createChallengeLoader, CHALLENGE_REGISTRY } = require('../../src/challenge-loader');
const { createApp } = require('../../src/server');

test('all ten Linux challenges (5 beginner + 5 intermediate) load and validate successfully', () => {
  const loader = createChallengeLoader();
  const val = loader.validateAll();
  assert.equal(val.total, 10);
  assert.equal(val.validCount, 10);

  const expected = [
    { id: 'LNX-CH-001', slug: 'file-directory-permissions' },
    { id: 'LNX-CH-002', slug: 'users-groups-access' },
    { id: 'LNX-CH-003', slug: 'the-missing-disk' },
    { id: 'LNX-CH-004', slug: 'mounting-filesystem-basics' },
    { id: 'LNX-CH-005', slug: 'process-service-fundamentals' },
    { id: 'LNX-CH-010', slug: 'broken-deployment' },
    { id: 'LNX-CH-020', slug: 'disk-pressure' },
    { id: 'LNX-CH-030', slug: 'process-resource' },
    { id: 'LNX-CH-040', slug: 'systemd-troubleshooting' },
    { id: 'LNX-CH-050', slug: 'network-outage' },
  ];

  for (const exp of expected) {
    const res = val.results.find((r) => r.id === exp.id && r.slug === exp.slug);
    assert.ok(res, `Missing validation result for ${exp.id}`);
    assert.equal(res.valid, true, `${exp.id} (${exp.slug}) failed validation`);
  }
});

test('getDomains() returns the registered Linux domain with correct challenge count', () => {
  const loader = createChallengeLoader();
  const domains = loader.getDomains();
  assert.equal(domains.length, 1);
  assert.equal(domains[0].id, 'linux');
  assert.equal(domains[0].title, 'Linux Troubleshooting');
  assert.equal(domains[0].count, 10);
});

test('listChallenges("linux") returns summaries for all 10 challenges in registry order', () => {
  const loader = createChallengeLoader();
  const list = loader.listChallenges('linux');
  assert.equal(list.length, 10);

  const slugs = list.map((c) => c.slug);
  assert.deepEqual(slugs, [
    'file-directory-permissions',
    'users-groups-access',
    'the-missing-disk',
    'mounting-filesystem-basics',
    'process-service-fundamentals',
    'broken-deployment',
    'disk-pressure',
    'process-resource',
    'systemd-troubleshooting',
    'network-outage',
  ]);

  for (const c of list) {
    assert.ok(c.id.startsWith('LNX-CH-'));
    assert.equal(c.domain, 'linux');
    assert.ok(c.title && typeof c.title === 'string');
    assert.ok(c.level === 'beginner' || c.level === 'intermediate');
    assert.ok(c.minutes >= 10);
    assert.ok(c.summary && typeof c.summary === 'string');
    assert.ok(c.tasksCount >= 4);
    assert.ok(c.stepsCount >= 5);
    // Ensure no filesystem paths or solutions are exposed
    assert.equal(c.dir, undefined);
    assert.equal(c.checkFile, undefined);
    assert.equal(c.solutionFile, undefined);
  }
});

test('getChallenge("linux", slug) returns complete, sanitized detail without path leakage', () => {
  const loader = createChallengeLoader();

  for (const reg of CHALLENGE_REGISTRY.linux) {
    const detail = loader.getChallenge('linux', reg.slug);
    assert.ok(detail, `Failed to load detail for ${reg.slug}`);
    assert.equal(detail.id, reg.id);
    assert.equal(detail.slug, reg.slug);
    assert.equal(detail.domain, 'linux');
    assert.ok(detail.title);
    assert.ok(detail.summary);
    assert.ok(Array.isArray(detail.resources));
    assert.ok(Array.isArray(detail.steps) && detail.steps.length > 0);

    for (const step of detail.steps) {
      assert.ok(step.id);
      assert.ok(step.type === 'lesson' || step.type === 'task');
      assert.ok(step.title);
      assert.ok(step.body);
      // Ensure step paths are not leaked to public projections
      assert.equal(step.checkFile, undefined);
      assert.equal(step.solutionFile, undefined);
      assert.equal(step.setupFile, undefined);
    }

    // Verify raw JSON string does not contain internal paths
    const jsonStr = JSON.stringify(detail);
    assert.equal(jsonStr.includes('/checks/'), false);
    assert.equal(jsonStr.includes('/solutions/'), false);
    assert.equal(jsonStr.includes('/app/challenges'), false);
  }
});

test('unknown domain or unknown slug fails safely with null', () => {
  const loader = createChallengeLoader();
  assert.equal(loader.listChallenges('windows'), null);
  assert.equal(loader.listChallenges(''), null);
  assert.equal(loader.getChallenge('linux', 'nonexistent-challenge'), null);
  assert.equal(loader.getChallenge('windows', 'broken-deployment'), null);
});

test('path traversal attempts are strictly rejected', () => {
  const loader = createChallengeLoader();
  const traversalSlugs = [
    '..',
    '../..',
    '../../etc',
    '../disk-pressure',
    'broken-deployment/../disk-pressure',
    '....//....//etc',
    '%2e%2e',
    '%2e%2e%2f',
    '.',
    './broken-deployment',
    'broken-deployment\0',
  ];

  for (const bad of traversalSlugs) {
    assert.equal(loader.getChallenge('linux', bad), null, `Traversal ${bad} was not rejected!`);
    assert.equal(loader.getChallenge(bad, 'broken-deployment'), null, `Domain traversal ${bad} was not rejected!`);
  }
});

test('symlink escape and boundary violations fail closed', () => {
  const tmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'ch-test-'));
  const fakeChallenges = path.join(tmpRoot, 'challenges');
  const outsideDir = path.join(tmpRoot, 'outside');
  fs.mkdirSync(path.join(fakeChallenges, 'linux'), { recursive: true });
  fs.mkdirSync(outsideDir, { recursive: true });

  // Create an outside challenge
  fs.writeFileSync(path.join(outsideDir, 'lab.yaml'), 'title: Escaped\nlevel: intermediate\nminutes: 15\nsummary: escaped\nsteps: [{id: s1, type: lesson, title: T, body: B}]\n');

  // Symlink it into fakeChallenges/linux/broken-deployment
  fs.symlinkSync(outsideDir, path.join(fakeChallenges, 'linux', 'broken-deployment'));

  const loader = createChallengeLoader({ challengesDir: fakeChallenges });
  const result = loader.getChallenge('linux', 'broken-deployment');
  assert.equal(result, null, 'Symlinked challenge directory must be rejected');

  fs.rmSync(tmpRoot, { recursive: true, force: true });
});

test('malformed YAML or missing required files fails closed', () => {
  const tmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'ch-malformed-'));
  const fakeLinux = path.join(tmpRoot, 'linux', 'broken-deployment');
  fs.mkdirSync(fakeLinux, { recursive: true });

  // Missing title
  fs.writeFileSync(path.join(fakeLinux, 'lab.yaml'), 'level: intermediate\nminutes: 15\nsummary: s\nsteps: []\n');
  const loader1 = createChallengeLoader({ challengesDir: tmpRoot });
  assert.equal(loader1.getChallenge('linux', 'broken-deployment'), null);

  // Task step missing checks/ and solutions/ files
  fs.writeFileSync(path.join(fakeLinux, 'lab.yaml'), 'title: T\nlevel: intermediate\nminutes: 15\nsummary: s\nsteps: [{id: t1, type: task, title: Task1, body: B1}]\n');
  const loader2 = createChallengeLoader({ challengesDir: tmpRoot });
  assert.equal(loader2.getChallenge('linux', 'broken-deployment'), null);

  fs.rmSync(tmpRoot, { recursive: true, force: true });
});

// Helper for making HTTP requests against local test server
function get(url) {
  return new Promise((resolve, reject) => {
    http.get(url, (res) => {
      let data = '';
      res.on('data', (c) => { data += c; });
      res.on('end', () => {
        let json = null;
        try { json = JSON.parse(data); } catch { /* not json */ }
        resolve({ status: res.statusCode, headers: res.headers, body: data, json });
      });
    }).on('error', reject);
  });
}

test('HTTP API: GET /api/challenges returns all registered domains', async () => {
  const { server } = createApp({ profile: 'local', port: 0 });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const port = server.address().port;

  try {
    const res = await get(`http://127.0.0.1:${port}/api/challenges`);
    assert.equal(res.status, 200);
    assert.ok(res.json);
    assert.ok(Array.isArray(res.json.domains));
    assert.equal(res.json.domains.length, 1);
    assert.equal(res.json.domains[0].id, 'linux');
    assert.equal(res.json.domains[0].count, 10);
  } finally {
    await new Promise((r) => server.close(r));
  }
});

test('HTTP API: GET /api/challenges/linux returns list of 10 challenges', async () => {
  const { server } = createApp({ profile: 'local', port: 0 });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const port = server.address().port;

  try {
    const res = await get(`http://127.0.0.1:${port}/api/challenges/linux`);
    assert.equal(res.status, 200);
    assert.ok(res.json);
    assert.equal(res.json.domain, 'linux');
    assert.equal(res.json.challenges.length, 10);
    assert.equal(res.json.challenges[0].id, 'LNX-CH-001');
    assert.equal(res.json.challenges[9].id, 'LNX-CH-050');
  } finally {
    await new Promise((r) => server.close(r));
  }
});

test('HTTP API: GET /api/challenges/linux/:slug returns detail metadata', async () => {
  const { server } = createApp({ profile: 'local', port: 0 });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const port = server.address().port;

  try {
    const res = await get(`http://127.0.0.1:${port}/api/challenges/linux/network-outage`);
    assert.equal(res.status, 200);
    assert.ok(res.json);
    assert.equal(res.json.id, 'LNX-CH-050');
    assert.equal(res.json.slug, 'network-outage');
    assert.equal(res.json.title, 'Network Outage: The Missing Route');
    assert.equal(res.json.steps.length, 6);
  } finally {
    await new Promise((r) => server.close(r));
  }
});

test('HTTP API: Unknown slugs and domains return 404 with JSON error', async () => {
  const { server } = createApp({ profile: 'local', port: 0 });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const port = server.address().port;

  try {
    const resSlug = await get(`http://127.0.0.1:${port}/api/challenges/linux/nonexistent`);
    assert.equal(resSlug.status, 404);
    assert.deepEqual(resSlug.json, { error: 'unknown challenge' });

    const resDomain = await get(`http://127.0.0.1:${port}/api/challenges/nonexistent`);
    assert.equal(resDomain.status, 404);
    assert.deepEqual(resDomain.json, { error: 'unknown domain' });
  } finally {
    await new Promise((r) => server.close(r));
  }
});

test('HTTP API: Path traversal attempts return 404 without crashing', async () => {
  const { server } = createApp({ profile: 'local', port: 0 });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const port = server.address().port;

  try {
    const res1 = await get(`http://127.0.0.1:${port}/api/challenges/linux/..%2f..%2fetc`);
    assert.equal(res1.status, 404);

    const res2 = await get(`http://127.0.0.1:${port}/api/challenges/linux/..`);
    assert.equal(res2.status, 404);
  } finally {
    await new Promise((r) => server.close(r));
  }
});

test('HTTP API: Existing guided lab routes and home continue to function identically', async () => {
  const { server } = createApp({ profile: 'local', port: 0 });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const port = server.address().port;

  try {
    const home = await get(`http://127.0.0.1:${port}/`);
    assert.equal(home.status, 200);
    assert.ok(home.body.includes('Learn <span class="u line-devops">DevOps</span>'));

    const health = await get(`http://127.0.0.1:${port}/healthz`);
    assert.equal(health.status, 200);
    assert.equal(health.body, 'ok');

    const track = await get(`http://127.0.0.1:${port}/t/linux-fundamentals`);
    assert.equal(track.status, 200);
    assert.ok(track.body.includes('Linux Fundamentals'));

    const lab = await get(`http://127.0.0.1:${port}/lab/linux-fundamentals/navigating`);
    assert.equal(lab.status, 200);
    assert.ok(lab.body.includes('Navigating the filesystem'));
  } finally {
    await new Promise((r) => server.close(r));
  }
});
