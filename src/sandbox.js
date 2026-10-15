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

  // Check contract: `bash checks/<step>.sh`, cwd = learner home, exit 0 = pass.
  // The first stdout line (if any) is shown to the learner as the failure message.
  function runCheck(scriptPath, { home, uid, shellPid, historyFile, env = {} }) {
    return new Promise((resolve) => {
      const [file, args] = asUser(uid, home, 'bash', [scriptPath]);
      const child = spawn(file, args, {
        cwd: home,
        env: scriptEnv(home, { ...env, LAB_SHELL_PID: String(shellPid || ''), LAB_HISTORY: historyFile || '/dev/null' }),
        stdio: ['ignore', 'pipe', 'ignore'],
      });
      let out = '';
      child.stdout.on('data', (c) => { if (out.length < 2000) out += c; });
      const timer = setTimeout(() => child.kill('SIGKILL'), 5000);
      child.on('error', () => { clearTimeout(timer); resolve({ pass: false, message: 'check could not run' }); });
      child.on('close', (code) => {
        clearTimeout(timer);
        resolve({ pass: code === 0, message: out.split('\n')[0].trim() });
      });
    });
  }

  return { asUser, scriptEnv, removeTree, prepareHome, prepareHistory, runSetup, runCheck };
}

module.exports = { createSandbox };
