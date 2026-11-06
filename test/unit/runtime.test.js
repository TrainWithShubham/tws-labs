const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { createExecutionRuntime, createLocalProcessRuntime, hasVerifiedIsolation } = require('../../src/runtime');
const { createSandbox } = require('../../src/sandbox');

const LABS = path.join(__dirname, '..', '..', 'labs');

test('local process runtime provides complete contract and explicitly denies container isolation', () => {
  const sandbox = createSandbox({ labsDir: LABS });
  const runtime = createLocalProcessRuntime({
    cfg: { isLocal: true },
    sandbox,
    bootstrap: 'true',
  });

  assert.equal(runtime.name, 'local-process');
  assert.equal(runtime.isIsolated, false, 'Single-host Linux DAC is not per-session container/namespace isolation');
  assert.equal(typeof runtime.verifyIsolation, 'function');
  assert.equal(runtime.verifyIsolation(), false, 'Local process runtime explicitly confirms non-isolation');
  assert.equal(hasVerifiedIsolation(runtime), false, 'Server capability check rejects non-isolated runtime');
  assert.equal(typeof runtime.prepareHome, 'function');
  assert.equal(typeof runtime.prepareHistory, 'function');
  assert.equal(typeof runtime.removeTree, 'function');
  assert.equal(typeof runtime.runSetup, 'function');
  assert.equal(typeof runtime.runChallengeSetup, 'function');
  assert.equal(typeof runtime.runScript, 'function');
  assert.equal(typeof runtime.runCheck, 'function');
  assert.equal(typeof runtime.spawnTerminal, 'function');
  assert.equal(typeof runtime.cleanupSession, 'function');
});

test('createExecutionRuntime instantiates local runtime by default and fails closed on unsupported runtimes', () => {
  const sandbox = createSandbox({ labsDir: LABS });

  const def = createExecutionRuntime({}, { sandbox, bootstrap: 'true' });
  assert.equal(def.name, 'local-process');

  const explicitLocal = createExecutionRuntime({ executionRuntime: 'local' }, { sandbox, bootstrap: 'true' });
  assert.equal(explicitLocal.name, 'local-process');

  assert.throws(
    () => createExecutionRuntime({ executionRuntime: 'kubernetes' }, { sandbox, bootstrap: 'true' }),
    /Kubernetes execution runtime is not yet enabled/
  );

  assert.throws(
    () => createExecutionRuntime({ executionRuntime: 'container' }, { sandbox, bootstrap: 'true' }),
    /Per-session isolated container runtime is not yet enabled/
  );

  assert.throws(
    () => createExecutionRuntime({ executionRuntime: 'unsupported-runtime' }, { sandbox, bootstrap: 'true' }),
    /Unknown EXECUTION_RUNTIME/
  );
});

test('hasVerifiedIsolation rejects unverified or spoofed isolation and requires server capability check', () => {
  assert.equal(hasVerifiedIsolation(null), false);
  assert.equal(hasVerifiedIsolation(undefined), false);
  assert.equal(hasVerifiedIsolation({}), false);
  assert.equal(hasVerifiedIsolation({ isIsolated: false }), false);
  assert.equal(hasVerifiedIsolation({ isIsolated: true }), false, 'Flag alone without verifyIsolation is rejected');
  assert.equal(hasVerifiedIsolation({ isIsolated: true, verifyIsolation: () => false }), false);
  assert.equal(hasVerifiedIsolation({ isIsolated: true, verifyIsolation: () => true }), true);
});

test('runtime session cleanup is safe, repeatable and handles already-cleaned paths', () => {
  const sandbox = createSandbox({ labsDir: LABS });
  const runtime = createLocalProcessRuntime({ cfg: { isLocal: true }, sandbox, bootstrap: 'true' });

  const tempHome = fs.mkdtempSync(path.join(os.tmpdir(), 'tws-rt-test-'));
  const tempHist = path.join(os.tmpdir(), `tws-rt-hist-${Date.now()}`);
  fs.writeFileSync(tempHist, 'echo test\n');

  assert.ok(fs.existsSync(tempHome));
  assert.ok(fs.existsSync(tempHist));

  // First cleanup pass
  runtime.cleanupSession({
    shell: { kill: () => {} },
    pid: null,
    uid: undefined,
    home: tempHome,
    historyFile: tempHist,
  });

  assert.ok(!fs.existsSync(tempHome), 'home deleted');
  assert.ok(!fs.existsSync(tempHist), 'history deleted');

  // Idempotent second cleanup pass must not throw
  assert.doesNotThrow(() => {
    runtime.cleanupSession({
      shell: null,
      pid: null,
      uid: undefined,
      home: tempHome,
      historyFile: tempHist,
    });
  });
});
