// start_local_labs.sh, driven with a fake `docker` on PATH that records its arguments: no daemon, no containers.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const SCRIPT = path.join(__dirname, '..', '..', 'start_local_labs.sh');
const hasBash = spawnSync('bash', ['-c', 'true']).status === 0;
// The image ships no start script or docs (only src, scripts and labs), so these run in a checkout and in CI's native job.
const inCheckout = fs.existsSync(SCRIPT);

function run(args, env = {}) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'start-'));
  const log = path.join(dir, 'docker.log');
  fs.writeFileSync(path.join(dir, 'docker'), `#!/bin/sh\necho "$@" >> "${log}"\nexit 0\n`, { mode: 0o755 });
  const clean = { PATH: `${dir}:${process.env.PATH}`, HOME: dir };
  const r = spawnSync('bash', [SCRIPT, ...args], { env: { ...clean, ...env }, encoding: 'utf8' });
  const calls = fs.existsSync(log) ? fs.readFileSync(log, 'utf8').trim().split('\n') : [];
  return { status: r.status, out: r.stdout + r.stderr, calls };
}
const t = (name, fn) => test(name, { skip: (!hasBash && 'needs bash') || (!inCheckout && 'not in a checkout (the image has no start script)') }, fn);

t('stop uses the plain compose file by default', () => {
  const r = run(['stop']);
  assert.equal(r.status, 0, r.out);
  assert.ok(r.calls.includes('compose down'), r.calls.join('\n'));
});

t('AWS=1 without credentials refuses to start, explains why, and never touches Docker compose', () => {
  const r = run([], { AWS: '1' });
  assert.notEqual(r.status, 0);
  assert.match(r.out, /AWS_ACCESS_KEY_ID/);
  assert.match(r.out, /docs\/aws-labs\.md/);
  assert.ok(!r.calls.some((c) => c.startsWith('compose')), 'no compose call before the credentials check');
});

t('AWS=1 with credentials uses both compose files, and the output never shows the keys', () => {
  const r = run(['stop'], { AWS: '1', AWS_ACCESS_KEY_ID: 'AKIAEXAMPLEKEY', AWS_SECRET_ACCESS_KEY: 'topsecretvalue' });
  assert.equal(r.status, 0, r.out);
  assert.ok(r.calls.includes('compose -f docker-compose.yml -f docker-compose.aws.yml down'), r.calls.join('\n'));
  assert.ok(!r.out.includes('AKIAEXAMPLEKEY') && !r.out.includes('topsecretvalue'));
  assert.ok(!r.calls.join('\n').includes('topsecretvalue'));
});

test('the AWS setup guide, role template and overlay files all exist and refer to each other', { skip: !inCheckout && 'not in a checkout' }, () => {
  const root = path.join(__dirname, '..', '..');
  const guide = fs.readFileSync(path.join(root, 'docs', 'aws-labs.md'), 'utf8');
  for (const f of ['deploy/learner-role.yaml', 'scripts/aws-lab-creds.sh', 'Dockerfile.aws', 'docker-compose.aws.yml']) assert.ok(fs.existsSync(path.join(root, f)), `${f} exists`);
  assert.match(guide, /deploy\/learner-role\.yaml/);
  assert.match(guide, /scripts\/aws-lab-creds\.sh/);
  assert.match(guide, /AWS=1 \.\/start_local_labs\.sh/);
});
