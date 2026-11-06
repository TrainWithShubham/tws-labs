const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');
const WebSocket = require('ws');
const { createApp } = require('../../src/server');
const { createSandbox } = require('../../src/sandbox');

function startServer(opts = {}) {
  const base = process.env.SANDBOX_DIR || os.tmpdir();
  fs.mkdirSync(base, { recursive: true });
  const sandboxDir = fs.mkdtempSync(path.join(base, 'ch-sess-'));
  fs.chmodSync(sandboxDir, 0o755);

  const app = createApp({
    sandboxDir,
    ...opts,
  });

  return new Promise((resolve) => {
    app.server.listen(0, '127.0.0.1', () => {
      const port = app.server.address().port;
      const sandbox = createSandbox({ labsDir: app.cfg.labsDir });
      resolve({
        ...app,
        port,
        sandbox,
        sandboxDir,
        origin: `http://127.0.0.1:${port}`,
        stop: () => {
          app.server.close();
          try { fs.rmSync(sandboxDir, { recursive: true, force: true }); } catch { /* ignore */ }
        },
      });
    });
  });
}

function request(app, method, urlPath, { headers = {}, body, origin = true } = {}) {
  return new Promise((resolve, reject) => {
    const h = { ...headers };
    if (origin === true && method !== 'GET') h.Origin = app.origin;
    else if (typeof origin === 'string') h.Origin = origin;

    const data = body === undefined ? undefined : (typeof body === 'string' ? body : JSON.stringify(body));
    if (data !== undefined) {
      h['Content-Type'] = 'application/json';
      h['Content-Length'] = Buffer.byteLength(data);
    }

    const req = require('http').request({ host: '127.0.0.1', port: app.port, path: urlPath, method, headers: h }, (res) => {
      let raw = '';
      res.on('data', (c) => { raw += c; });
      res.on('end', () => {
        let json = null;
        try { json = JSON.parse(raw); } catch { /* not json */ }
        resolve({ status: res.statusCode, headers: res.headers, body: raw, json });
      });
    });
    req.on('error', reject);
    if (data !== undefined) req.write(data);
    req.end();
  });
}

const post = (app, p, body, o = {}) => request(app, 'POST', p, { ...o, body });
const get = (app, p, o = {}) => request(app, 'GET', p, o);

const homeOf = (app, token) => path.join(app.sandboxDir, token.slice(0, 8));
const historyOf = (app, token) => path.join(app.sandboxDir, `.${token.slice(0, 8)}.history`);

// =============================================================================
// 1. Session Minting & Validation Tests
// =============================================================================

test('POST /session mints a valid challenge session with correct metadata', async () => {
  const app = await startServer({ profile: 'local' });
  try {
    const res = await post(app, '/session', {
      type: 'challenge',
      domain: 'linux',
      challenge: 'broken-deployment',
    });

    assert.equal(res.status, 200);
    assert.ok(res.json.token);
    assert.equal(typeof res.json.token, 'string');
    assert.equal(res.json.token.length, 32);

    const s = app.store.get(res.json.token);
    assert.ok(s);
    assert.equal(s.meta.type, 'challenge');
    assert.equal(s.meta.domain, 'linux');
    assert.equal(s.meta.challenge, 'broken-deployment');
  } finally {
    app.stop();
  }
});

test('POST /session works with domain & challenge without explicit type', async () => {
  const app = await startServer({ profile: 'local' });
  try {
    const res = await post(app, '/session', {
      domain: 'linux',
      challenge: 'disk-pressure',
    });

    assert.equal(res.status, 200);
    assert.ok(res.json.token);

    const s = app.store.get(res.json.token);
    assert.ok(s);
    assert.equal(s.meta.type, 'challenge');
    assert.equal(s.meta.domain, 'linux');
    assert.equal(s.meta.challenge, 'disk-pressure');
  } finally {
    app.stop();
  }
});

test('POST /session rejects unknown challenge with 404', async () => {
  const app = await startServer({ profile: 'local' });
  try {
    const res = await post(app, '/session', {
      type: 'challenge',
      domain: 'linux',
      challenge: 'unknown-challenge-slug',
    });

    assert.equal(res.status, 404);
    assert.deepEqual(res.json, { error: 'unknown challenge' });
  } finally {
    app.stop();
  }
});

test('POST /session rejects unknown domain with 404', async () => {
  const app = await startServer({ profile: 'local' });
  try {
    const res = await post(app, '/session', {
      type: 'challenge',
      domain: 'unsupported-domain',
      challenge: 'broken-deployment',
    });

    assert.equal(res.status, 404);
    assert.deepEqual(res.json, { error: 'unknown challenge' });
  } finally {
    app.stop();
  }
});

test('POST /session rejects malformed or traversal domain/slug input with 404', async () => {
  const app = await startServer({ profile: 'local' });
  try {
    for (const bad of ['..', '../../etc', '%2e%2e', 'broken-deployment/../disk-pressure']) {
      const res = await post(app, '/session', {
        type: 'challenge',
        domain: 'linux',
        challenge: bad,
      });
      assert.equal(res.status, 404);
    }
  } finally {
    app.stop();
  }
});

test('POST /session enforces Origin guard (missing Origin returns 403)', async () => {
  const app = await startServer({ profile: 'local' });
  try {
    const res = await post(app, '/session', {
      type: 'challenge',
      domain: 'linux',
      challenge: 'broken-deployment',
    }, { origin: false });

    assert.equal(res.status, 403);
    assert.deepEqual(res.json, { error: 'forbidden' });
  } finally {
    app.stop();
  }
});

test('Challenge token cannot access guided lab tasks, and guided lab token cannot access challenge tasks', async () => {
  const app = await startServer({ profile: 'local' });
  try {
    // 1. Mint a challenge session
    const chRes = await post(app, '/session', {
      type: 'challenge',
      domain: 'linux',
      challenge: 'broken-deployment',
    });
    const chToken = chRes.json.token;

    // 2. Mint a guided lab session
    const labRes = await post(app, '/session', {
      track: 'linux-fundamentals',
      lab: 'files',
    });
    const labToken = labRes.json.token;

    // Challenge token trying to check a guided lab step 'mkdir' -> must fail 404
    const res1 = await post(app, '/lab/check', { token: chToken, stepId: 'mkdir' });
    assert.equal(res1.status, 404);
    assert.equal(res1.json.pass, false);

    // Guided lab token trying to check a challenge step 'fix-symlink' -> must fail 404
    const res2 = await post(app, '/lab/check', { token: labToken, stepId: 'fix-symlink' });
    assert.equal(res2.status, 404);
    assert.equal(res2.json.pass, false);
  } finally {
    app.stop();
  }
});

test('Expired challenge session token is rejected with 403', async () => {
  const app = await startServer({ profile: 'local' });
  try {
    const res = await post(app, '/session', {
      type: 'challenge',
      domain: 'linux',
      challenge: 'broken-deployment',
    });
    const { token } = res.json;

    // Expire the token
    app.store.expire(token);

    const checkRes = await post(app, '/lab/check', { token, stepId: 'fix-symlink' });
    assert.equal(checkRes.status, 403);
    assert.equal(checkRes.json.pass, false);
  } finally {
    app.stop();
  }
});

// =============================================================================
// 2. Execution & Grading Tests
// =============================================================================

test('POST /lab/check reports "Terminal is still connecting" before shellPid is set', async () => {
  const app = await startServer({ profile: 'local' });
  try {
    const res = await post(app, '/session', {
      type: 'challenge',
      domain: 'linux',
      challenge: 'broken-deployment',
    });
    const { token } = res.json;

    const checkRes = await post(app, '/lab/check', { token, stepId: 'fix-symlink' });
    assert.equal(checkRes.status, 200);
    assert.equal(checkRes.json.pass, false);
    assert.equal(checkRes.json.message, 'Terminal is still connecting.');

    const setupRes = await post(app, '/lab/setup', { token, stepId: 'fix-symlink' });
    assert.equal(setupRes.status, 200);
    assert.equal(setupRes.json.ok, false);
    assert.equal(setupRes.json.message, 'Terminal is still connecting.');
  } finally {
    app.stop();
  }
});

test('Challenge setup executes and task checker grades machine state', async () => {
  const app = await startServer({ profile: 'local' });
  try {
    const res = await post(app, '/session', {
      type: 'challenge',
      domain: 'linux',
      challenge: 'broken-deployment',
    });
    const { token } = res.json;
    const session = app.store.get(token);
    const home = homeOf(app, token);

    // 1. Prepare home and run setup.sh (as terminal connection does)
    app.sandbox.prepareHome(home, session.uid);
    const challenge = app.challengeLoader.getChallengeInternal('linux', 'broken-deployment');
    const setup = app.sandbox.runSetup(challenge.dir, home, session.uid, {});
    assert.equal(setup.code, 0, 'setup.sh must exit 0');

    // Verify incident directory structure was created by setup.sh
    assert.ok(fs.existsSync(path.join(home, 'deploy')));
    assert.ok(fs.lstatSync(path.join(home, 'deploy', 'bin', 'app-cli')).isSymbolicLink());
    assert.ok(fs.existsSync(path.join(home, 'deploy', 'config', 'app.env')));

    // 2. Mark session connected with shellPid
    app.sandbox.prepareHistory(historyOf(app, token), session.uid);
    app.store.markConnected(token, { shellPid: process.pid, home });

    // 3. Task 1: fix-symlink check BEFORE fix -> must FAIL
    const checkBefore = await post(app, '/lab/check', { token, stepId: 'fix-symlink' });
    assert.equal(checkBefore.status, 200);
    assert.equal(checkBefore.json.pass, false);
    assert.ok(checkBefore.json.message);

    // 4. Apply the fix in the sandbox home: point app-cli symlink to app-cli-v2
    fs.unlinkSync(path.join(home, 'deploy', 'bin', 'app-cli'));
    fs.symlinkSync('app-cli-v2', path.join(home, 'deploy', 'bin', 'app-cli'));

    // 5. Task 1: fix-symlink check AFTER fix -> must PASS
    const checkAfter = await post(app, '/lab/check', { token, stepId: 'fix-symlink' });
    assert.equal(checkAfter.status, 200);
    assert.equal(checkAfter.json.pass, true);
    assert.equal(checkAfter.json.message, '');
  } finally {
    app.stop();
  }
});

test('Challenge setup on skip-ahead executes task setup script', async () => {
  const app = await startServer({ profile: 'local' });
  try {
    const res = await post(app, '/session', {
      type: 'challenge',
      domain: 'linux',
      challenge: 'broken-deployment',
    });
    const { token } = res.json;
    const session = app.store.get(token);
    const home = homeOf(app, token);

    app.sandbox.prepareHome(home, session.uid);
    const challenge = app.challengeLoader.getChallengeInternal('linux', 'broken-deployment');
    app.sandbox.runSetup(challenge.dir, home, session.uid, {});
    app.store.markConnected(token, { shellPid: process.pid, home });

    // Skip to verify-deployment task
    const setupRes = await post(app, '/lab/setup', { token, stepId: 'verify-deployment' });
    assert.equal(setupRes.status, 200);
    assert.equal(setupRes.json.ok, true);

    // Verify task setup script created the required prereq state (e.g. app.env corrected)
    const envContent = fs.readFileSync(path.join(home, 'deploy', 'config', 'app.env'), 'utf8');
    assert.ok(envContent.includes('APP_ENV=production'));
  } finally {
    app.stop();
  }
});

test('Arbitrary path injection in stepId is rejected with 404', async () => {
  const app = await startServer({ profile: 'local' });
  try {
    const res = await post(app, '/session', {
      type: 'challenge',
      domain: 'linux',
      challenge: 'broken-deployment',
    });
    const { token } = res.json;
    const session = app.store.get(token);
    const home = homeOf(app, token);
    app.sandbox.prepareHome(home, session.uid);
    app.store.markConnected(token, { shellPid: process.pid, home });

    const maliciousIds = [
      '../../solutions/fix-symlink',
      '../setup/verify-deployment',
      '/etc/passwd',
      'fix-symlink.sh',
      'nonexistent-step',
    ];

    for (const badId of maliciousIds) {
      const checkRes = await post(app, '/lab/check', { token, stepId: badId });
      assert.equal(checkRes.status, 404);
      assert.equal(checkRes.json.pass, false);

      const setupRes = await post(app, '/lab/setup', { token, stepId: badId });
      assert.equal(setupRes.status, 404);
      assert.equal(setupRes.json.ok, false);
    }
  } finally {
    app.stop();
  }
});

test('Session cleanup removes sandbox workspace directory', async () => {
  const app = await startServer({ profile: 'local' });
  try {
    const res = await post(app, '/session', {
      type: 'challenge',
      domain: 'linux',
      challenge: 'network-outage',
    });
    const { token } = res.json;
    const session = app.store.get(token);
    const home = homeOf(app, token);

    app.sandbox.prepareHome(home, session.uid);
    assert.ok(fs.existsSync(home), 'Sandbox home must exist');

    // Simulate session teardown
    app.sandbox.removeTree(home);
    app.sandbox.removeTree(historyOf(app, token));
    app.store.expire(token);

    assert.equal(fs.existsSync(home), false, 'Sandbox directory must be deleted on cleanup');
    assert.equal(app.store.has(token), false, 'Session must be expired in store');
  } finally {
    app.stop();
  }
});

// =============================================================================
// 3. WebSocket Terminal Guards
// =============================================================================

test('WebSocket /ws rejects invalid or missing token with 4001', async () => {
  const app = await startServer({ profile: 'local' });
  try {
    const ws = new WebSocket(`ws://127.0.0.1:${app.port}/ws?token=nonexistent00000000000000000000`, {
      headers: { Origin: app.origin },
    });

    const code = await new Promise((resolve) => {
      ws.on('close', (closeCode) => resolve(closeCode));
      ws.on('error', () => {});
    });

    assert.equal(code, 4001);
  } finally {
    app.stop();
  }
});

test('WebSocket /ws rejects connection without Origin header', async () => {
  const app = await startServer({ profile: 'local' });
  try {
    const res = await post(app, '/session', {
      type: 'challenge',
      domain: 'linux',
      challenge: 'broken-deployment',
    });
    const { token } = res.json;

    // Connect without Origin header
    const ws = new WebSocket(`ws://127.0.0.1:${app.port}/ws?token=${token}`);

    const errorStatus = await new Promise((resolve) => {
      ws.on('unexpected-response', (req, res) => {
        resolve(res.statusCode);
      });
      ws.on('error', () => resolve(true));
      ws.on('open', () => resolve(false));
    });

    // Guard rejects upgrade request with 401 Unauthorized or 403 Forbidden
    assert.ok(errorStatus === 401 || errorStatus === 403 || errorStatus === true);
  } finally {
    app.stop();
  }
});

// =============================================================================
// 4. Solution Protection Tests
// =============================================================================

test('Reference solutions are not exposed through HTTP routes or metadata', async () => {
  const app = await startServer({ profile: 'local' });
  try {
    // 1. Direct GET requests for solution files return 404
    const res1 = await get(app, '/challenges/linux/broken-deployment/solutions/fix-symlink.sh');
    assert.equal(res1.status, 404);

    const res2 = await get(app, '/solutions/fix-symlink.sh');
    assert.equal(res2.status, 404);

    // 2. Metadata discovery API does not expose solution files or contents
    const res3 = await get(app, '/api/challenges/linux/broken-deployment');
    assert.equal(res3.status, 200);
    const bodyStr = JSON.stringify(res3.json);
    assert.equal(bodyStr.includes('solutions/'), false);
    assert.equal(bodyStr.includes('checks/'), false);
    assert.equal(bodyStr.includes('solutionFile'), false);
  } finally {
    app.stop();
  }
});

// =============================================================================
// 5. Guided-Lab Regression Tests
// =============================================================================

test('Guided lab session creation and checking continue to work identically', async () => {
  const app = await startServer({ profile: 'local' });
  try {
    // 1. Mint guided lab session
    const m = await post(app, '/session', { track: 'linux-fundamentals', lab: 'files' });
    assert.equal(m.status, 200);
    const { token } = m.json;
    const session = app.store.get(token);
    const home = homeOf(app, token);

    // 2. Check before shellPid set returns "Terminal is still connecting"
    const preCheck = await post(app, '/lab/check', { token, stepId: 'mkdir' });
    assert.equal(preCheck.status, 200);
    assert.equal(preCheck.json.pass, false);
    assert.equal(preCheck.json.message, 'Terminal is still connecting.');

    // 3. Mark connected and prepare home
    app.sandbox.prepareHome(home, session.uid);
    app.sandbox.prepareHistory(historyOf(app, token), session.uid);
    app.store.markConnected(token, { shellPid: process.pid, home });

    // 4. Check 'mkdir' before directory exists -> must FAIL
    const chkBefore = await post(app, '/lab/check', { token, stepId: 'mkdir' });
    assert.equal(chkBefore.status, 200);
    assert.equal(chkBefore.json.pass, false);

    // 5. Create 'workspace' directory
    fs.mkdirSync(path.join(home, 'workspace'), { recursive: true });

    // 6. Check 'mkdir' after directory exists -> must PASS
    const chkAfter = await post(app, '/lab/check', { token, stepId: 'mkdir' });
    assert.equal(chkAfter.status, 200);
    assert.equal(chkAfter.json.pass, true);
    assert.equal(chkAfter.json.message, '');
  } finally {
    app.stop();
  }
});

test('hosted access policies: gated by default, token validation, and PUBLIC_CHALLENGES decoupling', async () => {
  // Test 1: Hosted with default gating (requires invite token)
  const hostedApp = await startServer({
    profile: 'hosted',
    env: { LAB_ACCESS_TOKENS: 'secret-token-123' },
  });
  try {
    // A. Challenge request without token -> 401 token-required
    const unauth = await post(hostedApp, '/session', {
      type: 'challenge',
      domain: 'linux',
      challenge: 'file-directory-permissions',
    });
    assert.equal(unauth.status, 401);
    assert.equal(unauth.json.error, 'token-required');

    // B. Challenge request with wrong token -> 401 token-required
    const wrong = await post(hostedApp, '/session', {
      type: 'challenge',
      domain: 'linux',
      challenge: 'file-directory-permissions',
    }, { headers: { 'x-lab-token': 'wrong-token' } });
    assert.equal(wrong.status, 401);

    // C. Challenge request with valid token fails closed with 403 on non-isolated runtime:
    // A valid invite token is NOT proof of trust; hosted execution must be disabled on local-process
    const auth = await post(hostedApp, '/session', {
      type: 'challenge',
      domain: 'linux',
      challenge: 'file-directory-permissions',
    }, { headers: { 'x-lab-token': 'secret-token-123' } });
    assert.equal(auth.status, 403);
    assert.equal(auth.json.error, 'untrusted-execution-disabled');
  } finally {
    hostedApp.stop();
  }

  // Test 2: Hosted with PUBLIC_CHALLENGES enabled: browsing is public, but shell execution fails closed without isolated runtime
  const publicChallApp = await startServer({
    profile: 'hosted',
    env: {
      PUBLIC_CHALLENGES: '1',
      LAB_ACCESS_TOKENS: 'member-only-code',
    },
  });
  try {
    // A. Public challenge execution fails closed with 403 on non-isolated runtime
    const openRes = await post(publicChallApp, '/session', {
      type: 'challenge',
      domain: 'linux',
      challenge: 'file-directory-permissions',
    });
    assert.equal(openRes.status, 403);
    assert.equal(openRes.json.error, 'untrusted-execution-disabled');

    // B. Even WITH an invite code, challenge execution still fails closed on non-isolated runtime (token != isolation)
    const authChall = await post(publicChallApp, '/session', {
      type: 'challenge',
      domain: 'linux',
      challenge: 'file-directory-permissions',
    }, { headers: { 'x-lab-token': 'member-only-code' } });
    assert.equal(authChall.status, 403);
    assert.equal(authChall.json.error, 'untrusted-execution-disabled');

    // C. Guided lab still requires an invite code
    const labRes = await post(publicChallApp, '/session', {
      track: 'linux-fundamentals',
      lab: 'navigating',
    });
    assert.equal(labRes.status, 401);
    assert.equal(labRes.json.error, 'token-required');

    // D. Guided lab with valid invite code succeeds
    const labResAuth = await post(publicChallApp, '/session', {
      track: 'linux-fundamentals',
      lab: 'navigating',
    }, { headers: { 'x-lab-token': 'member-only-code' } });
    assert.equal(labResAuth.status, 200);
    assert.ok(labResAuth.json.token);
  } finally {
    publicChallApp.stop();
  }

  // Test 3: Verified isolated runtime allows untrusted challenge execution when PUBLIC_CHALLENGES=1
  const mockIsolatedRuntime = {
    name: 'mock-isolated-container',
    isIsolated: true,
    provider: 'isolated-container-broker',
    verifyIsolation: () => true,
    prepareHome: () => {},
    prepareHistory: () => {},
    removeTree: () => {},
    runSetup: () => ({ code: 0, out: '' }),
    runChallengeSetup: () => ({ code: 0, out: '' }),
    runScript: async () => ({ code: 0, out: '' }),
    runCheck: async () => ({ pass: true, message: '' }),
    spawnTerminal: () => ({ pid: 12345, write: () => {}, resize: () => {}, kill: () => {}, onData: () => {}, onExit: () => {} }),
    cleanupSession: () => {},
  };

  const isolatedApp = await startServer({
    profile: 'hosted',
    runtime: mockIsolatedRuntime,
    env: {
      PUBLIC_CHALLENGES: '1',
      LAB_ACCESS_TOKENS: 'member-only-code',
    },
  });
  try {
    // Challenge mints without token because runtime is verified isolated
    const openRes = await post(isolatedApp, '/session', {
      type: 'challenge',
      domain: 'linux',
      challenge: 'file-directory-permissions',
    });
    assert.equal(openRes.status, 200);
    assert.ok(openRes.json.token);

    // Guided lab still strictly requires an invite token!
    const labRes = await post(isolatedApp, '/session', {
      track: 'linux-fundamentals',
      lab: 'navigating',
    });
    assert.equal(labRes.status, 401);
    assert.equal(labRes.json.error, 'token-required');
  } finally {
    isolatedApp.stop();
  }

  // Test 4: Verified isolated runtime with gated challenges (PUBLIC_CHALLENGES not set)
  const isolatedGatedApp = await startServer({
    profile: 'hosted',
    runtime: mockIsolatedRuntime,
    env: {
      LAB_ACCESS_TOKENS: 'member-only-code',
    },
  });
  try {
    // Unauthenticated request -> 401 token-required
    const unauth = await post(isolatedGatedApp, '/session', {
      type: 'challenge',
      domain: 'linux',
      challenge: 'file-directory-permissions',
    });
    assert.equal(unauth.status, 401);
    assert.equal(unauth.json.error, 'token-required');

    // Authenticated request with verified isolated runtime -> 200 ok
    const auth = await post(isolatedGatedApp, '/session', {
      type: 'challenge',
      domain: 'linux',
      challenge: 'file-directory-permissions',
    }, { headers: { 'x-lab-token': 'member-only-code' } });
    assert.equal(auth.status, 200);
    assert.ok(auth.json.token);
  } finally {
    isolatedGatedApp.stop();
  }
});

// =============================================================================
// 7. Interactive Terminal & Real Shell WebSocket Flow
// =============================================================================

function canSpawnPty() {
  if (process.platform !== 'linux') return 'needs Linux';
  try { require('node-pty').spawn('/bin/sh', ['-c', 'true'], {}).kill(); } catch { return 'pty cannot spawn here'; }
  try {
    const { spawnSync } = require('node:child_process');
    const r = spawnSync('bash', ['-c', 'ulimit -u 256 2>/dev/null; (true)'], { timeout: 800 });
    if (r.status !== 0) return 'host user thread limit exceeds ulimit -u 256 (run in docker container)';
  } catch { return 'cannot fork subshell'; }
  return false;
}
const SKIP_PTY = canSpawnPty();

test('Complete Linux Challenge interactive terminal connection and task grading (end-to-end)', { skip: SKIP_PTY }, async () => {
  const app = await startServer({ profile: 'local' });
  try {
    for (const testSlug of ['file-directory-permissions', 'broken-deployment']) {
      // 1. Mint session
      const sessRes = await post(app, '/session', {
        type: 'challenge',
        domain: 'linux',
        challenge: testSlug,
      });
      assert.equal(sessRes.status, 200);
      const token = sessRes.json.token;

      let ws = null;
      try {
        // 2. Connect real WebSocket
        ws = new WebSocket(`ws://127.0.0.1:${app.port}/ws?token=${token}`, {
          headers: { Origin: app.origin },
        });

        let bannerReceived = false;
        const chunks = [];

        await new Promise((resolve, reject) => {
          ws.on('open', () => {
            ws.send('\u0000resize:80,24');
          });
          ws.on('message', (data) => {
            const str = data.toString();
            chunks.push(str);
            if (str.includes('$') || str.includes('#') || chunks.join('').length > 10) {
              bannerReceived = true;
              resolve();
            }
          });
          ws.on('error', reject);
          setTimeout(resolve, 3000);
        });

        // Verify shell connected in store
        const session = app.store.get(token);
        assert.ok(session);
        assert.ok(session.shellPid, `${testSlug}: session shellPid must be registered`);

        // 3. Verify task check fails before repair
        const firstTaskId = testSlug === 'file-directory-permissions' ? 'fix-exec-bit' : 'fix-symlink';
        const checkBefore = await post(app, '/lab/check', { token, stepId: firstTaskId });
        assert.equal(checkBefore.status, 200);
        assert.equal(checkBefore.json.pass, false, `${testSlug}: check must fail before fix`);

        // 4. Send shell command through WebSocket to fix the issue
        if (testSlug === 'file-directory-permissions') {
          ws.send('chmod +x deploy/scripts/backup.sh\r');
        } else {
          ws.send('cd deploy/bin && ln -sf app-cli-v2 app-cli\r');
        }

        // Wait a moment for bash to execute the command in the sandbox
        await new Promise((r) => setTimeout(r, 600));

        // 5. Verify task check passes after repair
        const checkAfter = await post(app, '/lab/check', { token, stepId: firstTaskId });
        assert.equal(checkAfter.status, 200);
        assert.equal(checkAfter.json.pass, true, `${testSlug}: check must pass after fix`);
      } finally {
        // 6. Close WebSocket cleanly so session and shell process are terminated
        if (ws) {
          try {
            if (ws.readyState === WebSocket.OPEN) {
              await new Promise((resolve) => {
                const timer = setTimeout(() => {
                  try { ws.terminate(); } catch {}
                  resolve();
                }, 1000);
                ws.once('close', () => {
                  clearTimeout(timer);
                  resolve();
                });
                ws.close();
              });
            } else if (ws.readyState !== WebSocket.CLOSED) {
              ws.terminate();
            }
          } catch {
            try { ws.terminate(); } catch {}
          }
          // Verify server-side session cleanup has completed
          const startWait = Date.now();
          while (app.store.has(token) && Date.now() - startWait < 1000) {
            await new Promise((r) => setTimeout(r, 20));
          }
          assert.equal(app.store.has(token), false, `${testSlug}: session must be cleaned up in store`);
        }
      }
    }
  } finally {
    app.stop();
  }
});
