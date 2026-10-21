const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createSandbox } = require('../../src/sandbox');

const hasBash = fs.existsSync('/bin/bash') || fs.existsSync('/usr/bin/bash');
const t = (name, fn) => test(name, { skip: !hasBash && 'needs bash' }, fn);

function slowCheck(seconds) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'check-timeout-'));
  const file = path.join(dir, 'slow.sh');
  fs.writeFileSync(file, `sleep ${seconds}\necho done\n`);
  return { dir, file };
}
const sandbox = () => createSandbox({ labsDir: path.join(__dirname, '..', '..', 'labs') });

t('a check that runs past its time limit fails with a message that says so', async () => {
  const { dir, file } = slowCheck(5);
  const r = await sandbox().runCheck(file, { home: dir, uid: undefined, timeoutMs: 300 });
  assert.equal(r.pass, false);
  assert.match(r.message, /took too long/i);
});

t('the limit is the caller\'s: a slower check passes when it is given longer', async () => {
  const { dir, file } = slowCheck(1);
  const r = await sandbox().runCheck(file, { home: dir, uid: undefined, timeoutMs: 5000 });
  assert.equal(r.pass, true);
  assert.equal(r.message, 'done');
});
