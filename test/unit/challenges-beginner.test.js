const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');
const { createSandbox } = require('../../src/sandbox');
const { createChallengeLoader } = require('../../src/challenge-loader');

const BEGINNER_SLUGS = [
  'file-directory-permissions',
  'users-groups-access',
  'the-missing-disk',
  'mounting-filesystem-basics',
  'process-service-fundamentals',
];

const CHALLENGES_ROOT = path.join(__dirname, '..', '..', 'challenges');

function runScript(scriptPath, cwd, env = {}) {
  return spawnSync('bash', [scriptPath], {
    cwd,
    env: {
      ...process.env,
      HOME: cwd,
      LAB_HOME: cwd,
      LAB_LIB: path.join(__dirname, '..', '..', 'labs', 'lib.sh'),
      ...env,
    },
    timeout: 5000,
    encoding: 'utf8',
  });
}

test('All 5 Beginner challenges: every task check fails after setup and passes after solution', () => {
  const sandbox = createSandbox({ labsDir: path.join(__dirname, '..', '..', 'labs') });
  const challengeLoader = createChallengeLoader({ challengesDir: CHALLENGES_ROOT });

  for (const slug of BEGINNER_SLUGS) {
    const challenge = challengeLoader.getChallengeInternal('linux', slug);
    assert.ok(challenge, `Challenge ${slug} must load`);
    const chDir = challenge.dir;
    const tmpHome = fs.mkdtempSync(path.join(os.tmpdir(), `tws-ch-beg-${slug}-`));

    try {
      // 1. Run challenge setup
      const setupResult = sandbox.runChallengeSetup(chDir, tmpHome, undefined, {
        isolateOutput: slug === 'process-service-fundamentals',
      });
      assert.equal(setupResult.code, 0, `Setup for ${slug} must exit 0: ${setupResult.error || ''}`);

      const taskSteps = challenge.steps.filter((s) => s.type === 'task');

      for (const step of taskSteps) {
        const checkPath = path.join(chDir, 'checks', `${step.id}.sh`);
        const solutionPath = path.join(chDir, 'solutions', `${step.id}.sh`);

        // 2. Check must fail before solution is applied
        const before = runScript(checkPath, tmpHome);
        assert.notEqual(before.status, 0, `Check ${slug}/${step.id} must fail before solution`);

        // 3. Apply solution
        assert.ok(fs.existsSync(solutionPath), `Solution ${solutionPath} must exist`);
        const sol = runScript(solutionPath, tmpHome);
        assert.equal(sol.status, 0, `Solution ${slug}/${step.id} must exit 0: ${sol.stderr || sol.stdout}`);

        // 4. Check must pass after solution is applied
        const after = runScript(checkPath, tmpHome);
        assert.equal(after.status, 0, `Check ${slug}/${step.id} must pass after solution: ${after.stderr || after.stdout}`);
      }
    } finally {
      // Clean up background processes if any
      if (slug === 'process-service-fundamentals') {
        try {
          const pidFile = path.join(tmpHome, 'proc-incident', 'run', 'worker.pid');
          if (fs.existsSync(pidFile)) {
            const pid = parseInt(fs.readFileSync(pidFile, 'utf8').trim(), 10);
            if (pid) process.kill(pid, 'SIGKILL');
          }
        } catch {}
      }
      try {
        const cacheDir = path.join(tmpHome, 'deploy', 'cache');
        if (fs.existsSync(cacheDir)) {
          fs.chmodSync(cacheDir, 0o755);
        }
      } catch {}
      try {
        fs.rmSync(tmpHome, { recursive: true, force: true });
      } catch {}
    }
  }
});
