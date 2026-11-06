const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { createSandbox } = require('../../src/sandbox');

test('runSetup retains original direct execution behavior for guided labs', () => {
  const sandbox = createSandbox({ labsDir: path.join(__dirname, '..', '..', 'labs') });
  const tmpHome = fs.mkdtempSync(path.join(os.tmpdir(), 'tws-setup-test-'));
  const testDir = fs.mkdtempSync(path.join(os.tmpdir(), 'tws-setup-lab-'));

  try {
    // A standard setup.sh
    const script = path.join(testDir, 'setup.sh');
    fs.writeFileSync(script, '#!/bin/bash\necho "guided lab setup standard"\ntouch "$HOME/created.txt"\n', { mode: 0o755 });

    const res = sandbox.runSetup(testDir, tmpHome, undefined, {});
    assert.equal(res.code, 0);
    assert.match(res.out, /guided lab setup standard/);
    assert.ok(fs.existsSync(path.join(tmpHome, 'created.txt')));

    // Ensure no .challenge-setup.log or .setup.log was ever created
    assert.ok(!fs.existsSync(path.join(tmpHome, '.challenge-setup.log')));
    assert.ok(!fs.existsSync(path.join(tmpHome, '.setup.log')));
  } finally {
    fs.rmSync(tmpHome, { recursive: true, force: true });
    fs.rmSync(testDir, { recursive: true, force: true });
  }
});

test('runChallengeSetup runs without output redirection when not needed', () => {
  const sandbox = createSandbox({ labsDir: path.join(__dirname, '..', '..', 'labs') });
  const tmpHome = fs.mkdtempSync(path.join(os.tmpdir(), 'tws-ch-setup-std-'));
  const testDir = fs.mkdtempSync(path.join(os.tmpdir(), 'tws-ch-std-dir-'));

  try {
    const script = path.join(testDir, 'setup.sh');
    fs.writeFileSync(script, '#!/bin/bash\necho "standard challenge setup"\n', { mode: 0o755 });

    const res = sandbox.runChallengeSetup(testDir, tmpHome, undefined, {});
    assert.equal(res.code, 0);
    assert.match(res.out, /standard challenge setup/);
    assert.ok(!fs.existsSync(path.join(tmpHome, '.challenge-setup.log')));
  } finally {
    fs.rmSync(tmpHome, { recursive: true, force: true });
    fs.rmSync(testDir, { recursive: true, force: true });
  }
});

test('runChallengeSetup isolates output and handles unredirected background processes (LNX-CH-030 pattern)', () => {
  const sandbox = createSandbox({ labsDir: path.join(__dirname, '..', '..', 'labs') });
  const tmpHome = fs.mkdtempSync(path.join(os.tmpdir(), 'tws-ch-bg-home-'));
  const testDir = fs.mkdtempSync(path.join(os.tmpdir(), 'tws-ch-bg-dir-'));

  try {
    const script = path.join(testDir, 'setup.sh');
    // Simulates LNX-CH-030: spawns background daemon holding open stdio without redirection
    fs.writeFileSync(script, `#!/bin/bash
echo "spawning background daemon"
(
  COUNT=0
  while [ "$COUNT" -lt 100 ]; do
    sleep 1
    COUNT=$((COUNT + 1))
  done
) &
echo "setup completed"
`, { mode: 0o755 });

    const start = Date.now();
    // Explicitly flag isolateOutput or use process-resource pattern
    const res = sandbox.runChallengeSetup(testDir, tmpHome, undefined, {}, { isolateOutput: true });
    const elapsed = Date.now() - start;

    assert.equal(res.code, 0);
    assert.match(res.out, /setup completed/);
    // Crucial: Must return immediately (< 3000ms), NOT hang on the background subshell's pipes
    assert.ok(elapsed < 3000, `Expected elapsed < 3000ms, took ${elapsed}ms`);

    // Ensure temporary setup log is deleted from workspace
    assert.ok(!fs.existsSync(path.join(tmpHome, '.challenge-setup.log')));
  } finally {
    fs.rmSync(tmpHome, { recursive: true, force: true });
    fs.rmSync(testDir, { recursive: true, force: true });
  }
});

test('runChallengeSetup cleans up log file even on script error', () => {
  const sandbox = createSandbox({ labsDir: path.join(__dirname, '..', '..', 'labs') });
  const tmpHome = fs.mkdtempSync(path.join(os.tmpdir(), 'tws-ch-err-home-'));
  const testDir = fs.mkdtempSync(path.join(os.tmpdir(), 'tws-ch-err-dir-'));

  try {
    const script = path.join(testDir, 'setup.sh');
    fs.writeFileSync(script, `#!/bin/bash
echo "fatal error in challenge setup" >&2
exit 42
`, { mode: 0o755 });

    const res = sandbox.runChallengeSetup(testDir, tmpHome, undefined, {}, { isolateOutput: true });
    assert.equal(res.code, 42);
    assert.match(res.out, /fatal error in challenge setup/);

    // Guaranteed cleanup on error
    assert.ok(!fs.existsSync(path.join(tmpHome, '.challenge-setup.log')));
  } finally {
    fs.rmSync(tmpHome, { recursive: true, force: true });
    fs.rmSync(testDir, { recursive: true, force: true });
  }
});

test('runChallengeSetup cleans up log file on actual execution timeout', () => {
  const sandbox = createSandbox({ labsDir: path.join(__dirname, '..', '..', 'labs') });
  const tmpHome = fs.mkdtempSync(path.join(os.tmpdir(), 'tws-ch-tout-home-'));
  const testDir = fs.mkdtempSync(path.join(os.tmpdir(), 'tws-ch-tout-dir-'));

  try {
    const script = path.join(testDir, 'setup.sh');
    fs.writeFileSync(script, `#!/bin/bash
echo "starting long operation"
sleep 5
echo "done"
`, { mode: 0o755 });

    // Use a small timeout of 300ms to trigger actual timeout
    const res = sandbox.runChallengeSetup(testDir, tmpHome, undefined, {}, { isolateOutput: true, timeout: 300 });
    assert.equal(res.code, 1);

    // Log file must be deleted even on timeout
    assert.ok(!fs.existsSync(path.join(tmpHome, '.challenge-setup.log')));
  } finally {
    fs.rmSync(tmpHome, { recursive: true, force: true });
    fs.rmSync(testDir, { recursive: true, force: true });
  }
});

test('runChallengeSetup automatically isolates output for process-resource directory without explicit opts', () => {
  const sandbox = createSandbox({ labsDir: path.join(__dirname, '..', '..', 'labs') });
  const tmpHome = fs.mkdtempSync(path.join(os.tmpdir(), 'tws-ch-pr-home-'));
  const parentDir = fs.mkdtempSync(path.join(os.tmpdir(), 'tws-ch-pr-parent-'));
  const prDir = path.join(parentDir, 'process-resource');
  fs.mkdirSync(prDir);

  try {
    const script = path.join(prDir, 'setup.sh');
    fs.writeFileSync(script, `#!/bin/bash
(
  sleep 10
) &
echo "auto isolated setup"
`, { mode: 0o755 });

    const start = Date.now();
    // No opts.isolateOutput passed: automatic determination by basename 'process-resource'
    const res = sandbox.runChallengeSetup(prDir, tmpHome, undefined, {});
    const elapsed = Date.now() - start;

    assert.equal(res.code, 0);
    assert.match(res.out, /auto isolated setup/);
    assert.ok(elapsed < 3000, `Expected elapsed < 3000ms, took ${elapsed}ms`);
    assert.ok(!fs.existsSync(path.join(tmpHome, '.challenge-setup.log')));
  } finally {
    fs.rmSync(tmpHome, { recursive: true, force: true });
    fs.rmSync(parentDir, { recursive: true, force: true });
  }
});
