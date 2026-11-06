// Per-session sandbox home + script runner. Shared by the server (live sessions)
// and scripts/validate-labs.js (contributor / CI validation), so both exercise the
// same setup and check contract.
const fs = require('fs');
const path = require('path');
const { spawn, spawnSync } = require('child_process');

const GOSU = process.env.GOSU || '/usr/sbin/gosu';
const GITCONFIG = '[user]\n\tname = Learner\n\temail = learner@example.com\n[init]\n\tdefaultBranch = main\n[advice]\n\tdetachedHead = false\n';

function createSandbox({ labsDir }) {
  const libSh = path.join(labsDir, 'lib.sh');

  // As root (the container), scripts and shells drop to the session's own uid. gosu
  // accepts a numeric uid:gid with no passwd entry and clears supplementary groups,
  // but it overwrites $HOME, so env(1) pins it again.
  function asUser(uid, home, file, args) {
    if (uid === undefined) return [file, args];
    return [GOSU, [`${uid}:${uid}`, 'env', `HOME=${home}`, file, ...args]];
  }

  function scriptEnv(home, extra = {}) {
    return {
      PATH: process.env.PATH, HOME: home, LAB_HOME: home, LAB_LIB: libSh,
      LANG: 'C.UTF-8', GIT_CONFIG_NOSYSTEM: '1', GIT_TERMINAL_PROMPT: '0', ...extra,
    };
  }

  // Best-effort delete that never throws: it runs in socket-close handlers.
  function removeTree(p) {
    try { fs.rmSync(p, { recursive: true, force: true }); } catch { /* best effort */ }
  }

  // The learner's home is private to their uid (0700); nobody else can list or read it.
  function prepareHome(home, uid) {
    fs.mkdirSync(home, { recursive: true, mode: 0o700 });
    fs.chmodSync(home, 0o700);                       // before chown: once the learner owns it, root (without CAP_FOWNER) cannot
    fs.writeFileSync(path.join(home, '.gitconfig'), GITCONFIG);
    if (uid !== undefined) {
      fs.chownSync(path.join(home, '.gitconfig'), uid, uid);
      fs.chownSync(home, uid, uid);
    }
  }

  // The command log the `ran` helpers read. Owned by the session's uid, private (0600).
  function prepareHistory(file, uid) {
    fs.writeFileSync(file, '', { mode: 0o600 });
    if (uid !== undefined) fs.chownSync(file, uid, uid);
  }

  // Lab setup.sh seeds the learner's fresh home. Synchronous on purpose: it must
  // finish before the learner's shell starts.
  function runSetup(labDir, home, uid, extraEnv = {}) {
    const script = path.join(labDir, 'setup.sh');
    if (!fs.existsSync(script)) return { code: 0, out: '' };
    const [file, args] = asUser(uid, home, 'bash', [script]);
    const r = spawnSync(file, args, { cwd: home, env: scriptEnv(home, extraEnv), timeout: 15000, encoding: 'utf8' });
    return { code: r.status === null ? 1 : r.status, out: (r.stdout || '') + (r.stderr || '') };
  }

  // Explicit registry of challenges that require setup output isolation due to background supervisor daemons.
  const ISOLATED_SETUP_CHALLENGES = new Set(['process-resource', 'LNX-CH-030', 'process-service-fundamentals', 'LNX-CH-005']);

  function isChallengeOutputIsolated(challengeDir, opts = {}) {
    if (opts.isolateOutput !== undefined) return Boolean(opts.isolateOutput);
    const slug = path.basename(challengeDir);
    return ISOLATED_SETUP_CHALLENGES.has(slug);
  }

  // Challenge setup.sh execution path: runs the challenge's initial setup.sh.
  // Isolated to challenges: when a challenge script runs background processes holding open stdio
  // (e.g. LNX-CH-030), output is redirected to a temporary log inside the session workspace
  // to prevent spawnSync from blocking, and guaranteed cleaned up in finally.
  function runChallengeSetup(challengeDir, home, uid, extraEnv = {}, opts = {}) {
    const script = path.join(challengeDir, 'setup.sh');
    if (!fs.existsSync(script)) return { code: 0, out: '' };

    const needsRedirection = isChallengeOutputIsolated(challengeDir, opts);

    if (!needsRedirection) {
      return runSetup(challengeDir, home, uid, extraEnv);
    }

    const logFile = path.join(home, '.challenge-setup.log');
    const [file, args] = asUser(uid, home, 'bash', ['-c', 'exec bash "$1" > "$2" 2>&1', '--', script, logFile]);
    const r = spawnSync(file, args, { cwd: home, env: scriptEnv(home, extraEnv), timeout: opts.timeout || 15000 });
    let out = '';
    try {
      if (fs.existsSync(logFile)) {
        out = fs.readFileSync(logFile, 'utf8');
      }
    } catch { /* best effort read */ }
    finally {
      try { fs.rmSync(logFile, { force: true }); } catch { /* best effort cleanup */ }
    }
    return { code: r.status === null ? 1 : r.status, out };
  }

  // A task's setup/<task>.sh, run in the learner's live sandbox (async: it must not block other learners). Same user, home and
  // environment as the lab's setup.sh; killed after 15 s.
  function runScript(scriptPath, { home, uid, env = {} }) {
    return new Promise((resolve) => {
      const [file, args] = asUser(uid, home, 'bash', [scriptPath]);
      const child = spawn(file, args, { cwd: home, env: scriptEnv(home, env), stdio: ['ignore', 'pipe', 'pipe'] });
      let out = '';
      const take = (c) => { if (out.length < 4000) out += c; };
      child.stdout.on('data', take); child.stderr.on('data', take);
      const timer = setTimeout(() => child.kill('SIGKILL'), 15000);
      child.on('error', (e) => { clearTimeout(timer); resolve({ code: 1, out: String(e.message) }); });
      child.on('close', (code) => { clearTimeout(timer); resolve({ code: code === null ? 1 : code, out }); });
    });
  }

  // Check contract: `bash checks/<step>.sh`, cwd = learner home, exit 0 = pass.
  // The first stdout line (if any) is shown to the learner as the failure message.
  // A check gets 5 seconds. Account labs ask the real AWS API (CLI start-up, several calls, retries for eventual consistency), so the caller gives them longer.
  function runCheck(scriptPath, { home, uid, shellPid, historyFile, env = {}, timeoutMs = 5000 }) {
    return new Promise((resolve) => {
      const [file, args] = asUser(uid, home, 'bash', [scriptPath]);
      const child = spawn(file, args, {
        cwd: home,
        env: scriptEnv(home, { ...env, LAB_SHELL_PID: String(shellPid || ''), LAB_HISTORY: historyFile || '/dev/null' }),
        stdio: ['ignore', 'pipe', 'ignore'],
      });
      let out = '';
      child.stdout.on('data', (c) => { if (out.length < 2000) out += c; });
      let timedOut = false;
      const timer = setTimeout(() => { timedOut = true; child.kill('SIGKILL'); }, timeoutMs);
      child.on('error', () => { clearTimeout(timer); resolve({ pass: false, message: 'check could not run' }); });
      child.on('close', (code) => {
        clearTimeout(timer);
        resolve({ pass: code === 0 && !timedOut, message: timedOut ? 'The check took too long to finish. Press Check again in a moment.' : out.split('\n')[0].trim() });
      });
    });
  }

  return { asUser, scriptEnv, removeTree, prepareHome, prepareHistory, runSetup, runChallengeSetup, runScript, runCheck };
}

module.exports = { createSandbox };
