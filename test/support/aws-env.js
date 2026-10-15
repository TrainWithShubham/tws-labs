// Shared by the tests of AWS checks and helpers: a temp dir with a fake `aws` on PATH and a state directory.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const ROOT = path.join(__dirname, '..', '..');
const hasBash = spawnSync('bash', ['-c', 'true']).status === 0;

function awsEnv(extra = {}) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'fakeaws-'));
  const bin = path.join(dir, 'bin');
  fs.mkdirSync(bin);
  fs.writeFileSync(path.join(bin, 'aws'), `#!/bin/sh\nexec "${process.execPath}" "${path.join(__dirname, 'fake-aws.js')}" "$@"\n`, { mode: 0o755 });
  const state = path.join(dir, 'state');
  fs.mkdirSync(state);
  const home = path.join(dir, 'home');
  fs.mkdirSync(home);
  const env = {
    PATH: `${bin}:${path.dirname(process.execPath)}:/usr/bin:/bin`, HOME: home, LAB_HOME: home, LAB_LIB: path.join(ROOT, 'labs', 'lib.sh'),
    LAB_HISTORY: path.join(dir, 'history'), FAKE_AWS_DIR: state, AWS_REGION: 'us-east-1', AWS_ACCESS_KEY_ID: 'ASIAFAKE', ...extra,
  };
  fs.writeFileSync(env.LAB_HISTORY, '');
  const api = {
    env, dir, home, state: () => JSON.parse(fs.readFileSync(path.join(state, 'state.json'), 'utf8')),
    setState: (s) => fs.writeFileSync(path.join(state, 'state.json'), JSON.stringify(s)),
    calls: () => (fs.existsSync(path.join(state, 'calls.log')) ? fs.readFileSync(path.join(state, 'calls.log'), 'utf8').trim().split('\n') : []),
    typed: (...lines) => fs.appendFileSync(env.LAB_HISTORY, lines.join('\n') + '\n'),
    sh: (script, more = {}) => {
      const r = spawnSync('bash', ['-c', script], { cwd: home, env: { ...env, ...more }, encoding: 'utf8' });
      return { status: r.status, out: r.stdout, err: r.stderr };
    },
    check: (file, more = {}) => {
      const r = spawnSync('bash', [file], { cwd: home, env: { ...env, ...more }, encoding: 'utf8' });
      return { pass: r.status === 0, message: (r.stdout || '').split('\n')[0], err: r.stderr };
    },
  };
  return api;
}

module.exports = { awsEnv, hasBash, ROOT };
