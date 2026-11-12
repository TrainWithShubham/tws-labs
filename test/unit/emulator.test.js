// The AWS Emulator sidecar helpers: the learner-readable certificate copy and the health probe's quiet failures.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { ensureCa, checkHealth, configured, emulatorEnv } = require('../../src/emulator');
const { loadConfig } = require('../../src/config');

function cfgIn(dir, extra = {}) {
  return { emulator: { endpoint: 'https://127.0.0.1:9297', caSource: path.join(dir, 'ca.pem'), caFile: path.join(dir, 'copy.pem'), ...extra } };
}
const tmp = () => fs.mkdtempSync(path.join(os.tmpdir(), 'emu-'));

test('configuration: the emulator exists only on the local profile, and only when the compose overlay names its endpoint', () => {
  assert.equal(loadConfig({ LAB_PROFILE: 'local' }).emulator.endpoint, '');
  assert.equal(configured(loadConfig({ LAB_PROFILE: 'local' })), false);
  const local = loadConfig({ LAB_PROFILE: 'local', EMULATOR_ENDPOINT: 'https://127.0.0.1:9297', EMULATOR_CA_SOURCE: '/emulator-home/9297/ca.pem' });
  assert.equal(configured(local), true);
  assert.equal(local.emulator.caSource, '/emulator-home/9297/ca.pem');
  const hosted = loadConfig({ EMULATOR_ENDPOINT: 'https://127.0.0.1:9297', EMULATOR_CA_SOURCE: '/x' });
  assert.equal(configured(hosted), false, 'the hosted site never uses an emulator, even if the variable leaks in');
  assert.deepEqual(emulatorEnv(hosted), {});
});

test('ensureCa copies the public certificate to a world-readable file, and is safe to repeat', () => {
  const d = tmp();
  const cfg = cfgIn(d);
  fs.writeFileSync(cfg.emulator.caSource, 'CERT-ONE', { mode: 0o600 });
  assert.equal(ensureCa(cfg), true);
  assert.equal(fs.readFileSync(cfg.emulator.caFile, 'utf8'), 'CERT-ONE');
  assert.equal(fs.statSync(cfg.emulator.caFile).mode & 0o777, 0o644, 'learners can read it');
  assert.equal(ensureCa(cfg), true, 'again: nothing changes');
  fs.writeFileSync(cfg.emulator.caSource, 'CERT-TWO');   // the emulator regenerates its certificate on every start
  assert.equal(ensureCa(cfg), true);
  assert.equal(fs.readFileSync(cfg.emulator.caFile, 'utf8'), 'CERT-TWO', 'a restarted emulator\'s new certificate replaces the old copy');
  assert.deepEqual(fs.readdirSync(d).sort(), ['ca.pem', 'copy.pem'], 'no temporary file is left behind');
});

test('ensureCa reports false, without throwing, while the emulator has not written its certificate yet or nothing is configured', () => {
  const d = tmp();
  assert.equal(ensureCa(cfgIn(d)), false);
  assert.equal(ensureCa({ emulator: { endpoint: '', caSource: '', caFile: path.join(d, 'x') } }), false);
  assert.equal(ensureCa({}), false);
});

test('checkHealth answers false, quickly and quietly, when the emulator is absent, still starting or unreachable', async () => {
  const d = tmp();
  assert.equal(await checkHealth({ emulator: { endpoint: '', caSource: '', caFile: '' } }), false, 'not configured');
  assert.equal(await checkHealth(cfgIn(d)), false, 'no certificate yet');
  fs.writeFileSync(path.join(d, 'ca.pem'), 'not a certificate');
  assert.equal(await checkHealth(cfgIn(d, { endpoint: 'https://127.0.0.1:1' }), { timeoutMs: 500 }), false, 'nothing listening');
  assert.equal(await checkHealth(cfgIn(d, { endpoint: 'not a url' })), false, 'a bad endpoint');
});

// A repo-checkout test: the compose files are not copied into the image, so the image run skips it (the native CI job runs it).
const AWS_OVERLAY = path.join(__dirname, '..', '..', 'docker-compose.aws.yml');
test('the AWS CLI overlay raises the address-space cap: `aws s3 cp` aborts under the default 1 GiB cap (it needs about 2 GiB)', { skip: !fs.existsSync(AWS_OVERLAY) && 'docker-compose.aws.yml is not in the image' }, () => {
  const yaml = require('js-yaml');
  const overlay = yaml.load(fs.readFileSync(AWS_OVERLAY, 'utf8'));
  const kb = parseInt(overlay.services.labs.environment.LAB_ULIMIT_V_KB, 10);
  assert.ok(kb >= 2 * 1024 * 1024, `LAB_ULIMIT_V_KB is ${kb} KB; the CLI's transfer library needs at least 2 GiB`);
});
