// scripts/aws-lab-creds.sh, driven with a fake `aws` on PATH: it prints export lines for short-lived credentials, and refuses anything odd.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const SCRIPT = path.join(__dirname, '..', '..', 'scripts', 'aws-lab-creds.sh');
const hasBash = spawnSync('bash', ['-c', 'true']).status === 0;
const ROLE = 'arn:aws:iam::123456789012:role/tws-labs-learner';

function run(args, { awsOutput = 'ASIAEXAMPLE\tsecret/Key+1=\ttoken/ABC+def==', awsStatus = 0, noAws = false } = {}) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'creds-'));
  const log = path.join(dir, 'aws.log');
  if (!noAws) fs.writeFileSync(path.join(dir, 'aws'), `#!/bin/sh\necho "$@" >> "${log}"\n[ ${awsStatus} -eq 0 ] && printf '%s\\n' '${awsOutput}'\nexit ${awsStatus}\n`, { mode: 0o755 });
  const r = spawnSync('bash', [SCRIPT, ...args], { env: { PATH: `${dir}:/usr/bin:/bin`, HOME: dir }, encoding: 'utf8' });
  return { status: r.status, out: r.stdout, err: r.stderr, awsCalls: fs.existsSync(log) ? fs.readFileSync(log, 'utf8').trim().split('\n') : [] };
}
const t = (name, fn) => test(name, { skip: !hasBash && 'needs bash' }, fn);

t('prints export lines for one-hour credentials, and only those lines on stdout', () => {
  const r = run([ROLE]);
  assert.equal(r.status, 0, r.err);
  assert.deepEqual(r.out.trim().split('\n'), [
    "export AWS_ACCESS_KEY_ID='ASIAEXAMPLE'",
    "export AWS_SECRET_ACCESS_KEY='secret/Key+1='",
    "export AWS_SESSION_TOKEN='token/ABC+def=='",
  ]);
  assert.match(r.awsCalls[0], /sts assume-role --role-arn arn:aws:iam::123456789012:role\/tws-labs-learner/);
  assert.match(r.awsCalls[0], /--duration-seconds 3600/);
  assert.ok(!r.err.includes('secret/Key'), 'the secret is never written to stderr');
});

t('a different duration can be asked for, within what the learner role allows (900 to 14400 seconds)', () => {
  assert.match(run([ROLE, '--duration', '7200']).awsCalls[0], /--duration-seconds 7200/);
  assert.notEqual(run([ROLE, '--duration', '10']).status, 0);
  assert.equal(run([ROLE, '--duration', '14400']).status, 0);
  assert.notEqual(run([ROLE, '--duration', '14401']).status, 0, 'longer than the role can issue');
  assert.notEqual(run([ROLE, '--duration', '99999']).status, 0);
  assert.notEqual(run([ROLE, '--duration', 'abc']).status, 0);
});

t('anything that is not a role ARN is refused before AWS is called', () => {
  for (const bad of ['', 'tws-labs-learner', 'arn:aws:iam::123:role/x', 'arn:aws:iam::123456789012:user/me', `${ROLE}; rm -rf /`, "arn:aws:iam::123456789012:role/x'$(id)'"]) {
    const r = run(bad === '' ? [] : [bad]);
    assert.notEqual(r.status, 0, `accepted: ${bad}`);
    assert.deepEqual(r.awsCalls, [], `called aws for: ${bad}`);
    assert.equal(r.out, '', 'nothing on stdout for eval to run');
  }
});

t('a failed assume-role prints nothing on stdout, so eval cannot run half an answer', () => {
  const r = run([ROLE], { awsStatus: 255 });
  assert.notEqual(r.status, 0);
  assert.equal(r.out, '');
  assert.match(r.err, /assume-role failed/i);
});

t('values that are not plain credential characters are refused, so they can never inject shell', () => {
  const r = run([ROLE], { awsOutput: "ASIA'; echo hacked; '\tsecret\ttoken" });
  assert.notEqual(r.status, 0);
  assert.equal(r.out, '');
});

t('without the AWS CLI on this machine it says so', () => {
  const r = run([ROLE], { noAws: true });
  assert.notEqual(r.status, 0);
  assert.match(r.err, /AWS CLI/);
});
