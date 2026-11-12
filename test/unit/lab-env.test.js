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

// --- emulator labs (`requires: emulator`): the AWS Emulator sidecar, never the learner's real account ---
const { proofSkipReason: skipReason } = require('../../src/lab-env');
const EMU = { isLocal: true, emulator: { endpoint: 'https://127.0.0.1:9297', caSource: '/emulator-home/9297/ca.pem', caFile: '/tmp/tws-emulator-ca.pem' } };
const emu = { requires: 'emulator' };

test('an emulator lab gets the emulator endpoint, its certificate and dummy keys, and never the learner\'s real AWS variables or the server\'s secrets', () => {
  const env = labEnv(emu, EMU, SERVER);
  assert.equal(env.AWS_ENDPOINT_URL, 'https://127.0.0.1:9297');
  assert.equal(env.AWS_CA_BUNDLE, '/tmp/tws-emulator-ca.pem');
  assert.equal(env.AWS_ACCESS_KEY_ID, 'emulator');
  assert.equal(env.AWS_SECRET_ACCESS_KEY, 'emulator');
  assert.equal(env.AWS_REGION, 'us-east-1');
  assert.ok(!('AWS_SESSION_TOKEN' in env) && !('AWS_PROFILE' in env), 'no real credentials reach an emulator lab');
  for (const secret of ['LAB_ACCESS_TOKENS', 'ADMIN_TOKEN', 'USAGE_SALT', 'HOME']) assert.ok(!(secret in env), `${secret} is never passed`);
  assert.notEqual(env.AWS_ACCESS_KEY_ID, SERVER.AWS_ACCESS_KEY_ID);
});

test('an emulator lab with no emulator configured, or on the hosted profile, gets no environment', () => {
  assert.deepEqual(labEnv(emu, { isLocal: true, emulator: { endpoint: '', caSource: '', caFile: '/x' } }, SERVER), {});
  assert.deepEqual(labEnv(emu, { isLocal: true }, SERVER), {});
  assert.deepEqual(labEnv(emu, { ...EMU, isLocal: false }, SERVER), {});
});

test('the emulator environment is only for emulator labs: an account lab or a plain lab never gets it', () => {
  assert.ok(!('AWS_ENDPOINT_URL' in labEnv(aws, EMU, SERVER)), 'an account lab talks to real AWS, not the emulator');
  assert.deepEqual(labEnv({ requires: '' }, EMU, SERVER), {});
});

test('an emulator lab is skipped by the validator unless the emulator CI job says an emulator is running', () => {
  assert.match(skipReason(emu, {}), /needs the AWS Emulator/);
  assert.match(skipReason(emu, { TWS_PROVE_AWS: '1' }), /needs the AWS Emulator/, 'a real account is not consent to use the emulator');
  assert.equal(skipReason(emu, { TWS_PROVE_EMULATOR: '1' }), '');
  assert.match(skipReason({ requires: 'aws' }, { TWS_PROVE_EMULATOR: '1' }), /needs a real AWS account/, 'the emulator does not stand in for an account lab');
});

test('labs that talk to AWS or the emulator get a longer check limit than the 5-second default (the CLI starts slowly and resources settle)', () => {
  const { checkTimeoutMs } = require('../../src/lab-env');
  assert.equal(checkTimeoutMs({ requires: 'aws' }), 30000);
  assert.equal(checkTimeoutMs({ requires: 'emulator' }), 30000);
  assert.equal(checkTimeoutMs({ requires: '' }), undefined, 'an offline lab keeps the default');
  assert.equal(checkTimeoutMs(undefined), undefined);
});
