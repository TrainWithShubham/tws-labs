// The lib.sh helpers account labs use: aws_ready (a friendly, safe pre-flight), aws_account, aws_region_is and retry. Run against a fake aws.
const test = require('node:test');
const assert = require('node:assert/strict');
const { awsEnv, hasBash } = require('../support/aws-env');

const t = (name, fn) => test(name, { skip: !hasBash && 'needs bash' }, fn);
const LIB = '. "$LAB_LIB"; ';

t('aws_ready passes for a normal assumed-role identity and costs one identity call', () => {
  const e = awsEnv();
  const r = e.sh(`${LIB}aws_ready; echo ready`);
  assert.equal(r.status, 0, r.out);
  assert.match(r.out, /ready/);
  assert.equal(e.calls().filter((c) => c.startsWith('sts get-caller-identity')).length, 1);
});

t('aws_ready refuses the root user and says why, never printing keys', () => {
  const e = awsEnv({ FAKE_AWS_ARN: 'arn:aws:iam::123456789012:root', AWS_SECRET_ACCESS_KEY: 'supersecretvalue' });
  const r = e.sh(`${LIB}aws_ready`);
  assert.notEqual(r.status, 0);
  assert.match(r.out.split('\n')[0], /root/i);
  assert.ok(!r.out.includes('supersecretvalue') && !r.err.includes('supersecretvalue'));
});

t('aws_ready explains missing or expired credentials with the next step', () => {
  const e = awsEnv({ FAKE_AWS_DOWN: '1' });
  const r = e.sh(`${LIB}aws_ready`);
  assert.notEqual(r.status, 0);
  assert.match(r.out.split('\n')[0], /credentials/i);
  assert.match(r.out, /aws-labs\.md/);
});

t('aws_ready reports a missing aws command instead of failing silently', () => {
  const e = awsEnv();
  const r = e.sh(`${LIB}aws_ready`, { PATH: '/usr/bin:/bin' });
  assert.notEqual(r.status, 0);
  assert.match(r.out.split('\n')[0], /AWS=1/);
});

t('aws_account prints the account id, and aws_region_is compares the learner\'s region', () => {
  const e = awsEnv({ FAKE_AWS_ACCOUNT: '210987654321' });
  assert.equal(e.sh(`${LIB}aws_account`).out.trim(), '210987654321');
  assert.equal(e.sh(`${LIB}aws_region_is us-east-1`).status, 0);
  assert.notEqual(e.sh(`${LIB}aws_region_is eu-west-1`).status, 0);
  assert.equal(e.sh(`${LIB}aws_region_is us-east-1`, { AWS_REGION: '', AWS_DEFAULT_REGION: 'us-east-1' }).status, 0, 'falls back to AWS_DEFAULT_REGION');
  assert.notEqual(e.sh(`${LIB}aws_region_is us-east-1`, { AWS_REGION: '', AWS_DEFAULT_REGION: '' }).status, 0, 'unset is not a match');
});

t('retry runs a command until it succeeds, gives up after N tries, and returns the last status', () => {
  const e = awsEnv();
  const ok = e.sh(`${LIB}n=0; flaky() { n=$((n+1)); [ $n -ge 3 ]; }; retry 5 0 flaky; echo "tries=$n status=$?"`);
  assert.match(ok.out, /tries=3 status=0/);
  const bad = e.sh(`${LIB}n=0; never() { n=$((n+1)); return 7; }; retry 3 0 never; echo "tries=$n status=$?"`);
  assert.match(bad.out, /tries=3 status=7/);
});
