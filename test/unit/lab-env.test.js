const test = require('node:test');
const assert = require('node:assert/strict');
const { labEnv, AWS_ENV } = require('../../src/lab-env');

const SERVER = {
  AWS_ACCESS_KEY_ID: 'AKIAEXAMPLE', AWS_SECRET_ACCESS_KEY: 'secret', AWS_SESSION_TOKEN: 'tok', AWS_REGION: 'us-east-1',
  AWS_DEFAULT_REGION: 'us-east-1', AWS_PROFILE: 'learner', LAB_ACCESS_TOKENS: 'invite', ADMIN_TOKEN: 'adm', USAGE_SALT: 's', HOME: '/root',
};
const aws = { requires: 'aws' };

test('an AWS lab on the local profile gets the learner\'s AWS variables, and nothing else from the server', () => {
  const env = labEnv(aws, { isLocal: true }, SERVER);
  assert.deepEqual(Object.keys(env).sort(), [...AWS_ENV].sort());
  assert.equal(env.AWS_ACCESS_KEY_ID, 'AKIAEXAMPLE');
  for (const secret of ['LAB_ACCESS_TOKENS', 'ADMIN_TOKEN', 'USAGE_SALT', 'HOME']) assert.ok(!(secret in env), `${secret} is never passed`);
});

test('variables that are not set are not invented, and empty ones are dropped', () => {
  assert.deepEqual(labEnv(aws, { isLocal: true }, { AWS_REGION: 'eu-west-1', AWS_ACCESS_KEY_ID: '' }), { AWS_REGION: 'eu-west-1' });
  assert.deepEqual(labEnv(aws, { isLocal: true }, {}), {});
});

test('other labs never get AWS variables, even locally', () => {
  assert.deepEqual(labEnv({ requires: '' }, { isLocal: true }, SERVER), {});
  assert.deepEqual(labEnv({}, { isLocal: true }, SERVER), {});
  assert.deepEqual(labEnv(null, { isLocal: true }, SERVER), {});
});

test('the hosted profile never passes credentials, whatever the lab says', () => {
  assert.deepEqual(labEnv(aws, { isLocal: false }, SERVER), {});
});

const { proofSkipReason } = require('../../src/lab-env');

test('the offline validator skips account labs unless it was told it has a real account to prove them against', () => {
  assert.match(proofSkipReason({ requires: 'aws' }, {}), /needs a real AWS account/);
  assert.match(proofSkipReason({ requires: 'aws' }, { AWS_ACCESS_KEY_ID: 'AKIA' }), /needs a real AWS account/, 'keys alone are not consent to create resources');
  assert.equal(proofSkipReason({ requires: 'aws' }, { TWS_PROVE_AWS: '1' }), '');
  assert.equal(proofSkipReason({ requires: '' }, {}), '', 'offline labs are always proven');
  assert.equal(proofSkipReason({}, {}), '');
});
