// scripts/aws-lab-sweep.sh against the fake aws: a dry run by default, deletes only lab-prefixed or lab-tagged things, never root.
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { awsEnv, hasBash, ROOT } = require('../support/aws-env');

const SCRIPT = path.join(ROOT, 'scripts', 'aws-lab-sweep.sh');
const t = (name, fn) => test(name, { skip: !hasBash && 'needs bash' }, fn);
const sweep = (e, args = [], more = {}) => {
  const env = { ...e.env, ...more };
  const r = spawnSync('bash', [SCRIPT, ...args], { cwd: e.home, env, encoding: 'utf8' });
  return { status: r.status, out: r.stdout, err: r.stderr };
};
const withState = (buckets, volumes = []) => {
  const e = awsEnv();
  e.setState({ buckets: Object.fromEntries(buckets.map((b) => [b, { tags: [], versioning: '' }])), volumes: volumes.map((VolumeId) => ({ VolumeId })) });
  return e;
};

t('a dry run lists what it would delete and deletes nothing', () => {
  const e = withState(['tws-labs-123456789012-cli', 'my-production-data'], ['vol-1']);
  const r = sweep(e);
  assert.equal(r.status, 0, r.err);
  assert.match(r.out, /tws-labs-123456789012-cli/);
  assert.match(r.out, /vol-1/);
  assert.ok(!r.out.includes('my-production-data'), 'other buckets are never even listed');
  assert.match(r.out, /dry run/i);
  assert.equal(Object.keys(e.state().buckets).length, 2);
  assert.equal(e.state().volumes.length, 1);
  assert.ok(!e.calls().some((c) => /delete-/.test(c)), 'no delete call in a dry run');
});

t('--yes deletes the lab buckets and tagged volumes, and leaves everything else alone', () => {
  const e = withState(['tws-labs-123456789012-cli', 'tws-labs-123456789012-other', 'my-production-data'], ['vol-1', 'vol-2']);
  const r = sweep(e, ['--yes']);
  assert.equal(r.status, 0, r.err);
  assert.deepEqual(Object.keys(e.state().buckets), ['my-production-data']);
  assert.equal(e.state().volumes.length, 0);
  assert.match(r.out, /deleted/i);
});

t('it names the account and region first, and says so when there is nothing to clean', () => {
  const e = withState(['unrelated']);
  const r = sweep(e);
  assert.match(r.out, /123456789012/);
  assert.match(r.out, /us-east-1/);
  assert.match(r.out, /nothing to clean/i);
});

t('it refuses root credentials, missing credentials and unknown options, and deletes nothing', () => {
  const root = withState(['tws-labs-123456789012-cli']);
  const r1 = sweep(root, ['--yes'], { FAKE_AWS_ARN: 'arn:aws:iam::123456789012:root' });
  assert.notEqual(r1.status, 0);
  assert.match(r1.out + r1.err, /root/i);
  assert.equal(Object.keys(root.state().buckets).length, 1);
  assert.notEqual(sweep(withState([]), [], { FAKE_AWS_DOWN: '1' }).status, 0);
  assert.notEqual(sweep(withState([]), ['--everything']).status, 0);
});
