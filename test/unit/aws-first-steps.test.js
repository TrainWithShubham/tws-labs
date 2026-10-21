// The AWS CLI first steps lab, graded against the test-only fake aws: every task fails before its solution and passes after,
// near-misses are rejected, and no check changes the account. (The real-account proof is the scheduled AWS workflow.)
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { awsEnv, hasBash, ROOT } = require('../support/aws-env');

const LAB = path.join(ROOT, 'labs', 'aws', 'aws-cli-first-steps');
const t = (name, fn) => test(name, { skip: !hasBash && 'needs bash' }, fn);
const lines = (f) => fs.readFileSync(f, 'utf8').split('\n').filter((l) => l.trim() && !l.trim().startsWith('#'));
const TASKS = ['identity', 'make-bucket', 'tag-bucket', 'versioning', 'read-status', 'cleanup'];
const BUCKET = 'tws-labs-123456789012-cli';
const checkOf = (e, id, more) => e.check(path.join(LAB, 'checks', `${id}.sh`), more);
function solve(e, id) {
  const ls = lines(path.join(LAB, 'solutions', `${id}.sh`));
  e.typed(...ls);
  const r = e.sh(ls.join('\n'));
  assert.equal(r.status, 0, `solution ${id} ran: ${r.err}`);
}

t('every task fails before its solution and passes after it, in order', () => {
  const e = awsEnv();
  for (const id of TASKS) {
    assert.equal(checkOf(e, id).pass, false, `${id} must fail before its solution`);
    solve(e, id);
    const after = checkOf(e, id);
    assert.equal(after.pass, true, `${id} must pass after its solution: ${after.message}`);
  }
});

t('checks never change the account', () => {
  const e = awsEnv();
  for (const id of TASKS) { solve(e, id); checkOf(e, id); }
  const mutating = e.calls().filter((c) => /^(s3api (create|delete|put)-|ec2 delete-)/.test(c) && !c.includes('--tagging') );
  // only the solutions' own mutating calls appear, once each: create, put tagging, put versioning, delete
  assert.equal(mutating.length, 3 + 0, mutating.join('\n'));
});

t('the pre-flight guards every check: expired credentials and root credentials stop at once with a helpful line', () => {
  for (const id of TASKS) {
    const down = checkOf(awsEnv({ FAKE_AWS_DOWN: '1' }), id);
    assert.equal(down.pass, false);
    assert.match(down.message, /credentials/i, `${id}: expired`);
    const root = checkOf(awsEnv({ FAKE_AWS_ARN: 'arn:aws:iam::123456789012:root' }), id);
    assert.equal(root.pass, false);
    assert.match(root.message, /root/i, `${id}: root`);
  }
});

t('identity: the saved file must be this account\'s identity, and the command must have been run', () => {
  const e = awsEnv();
  fs.writeFileSync(path.join(e.home, 'identity.json'), JSON.stringify({ Account: '999999999999' }));
  e.typed('aws sts get-caller-identity > identity.json');
  assert.equal(checkOf(e, 'identity').pass, false, 'someone else\'s account id');
  const e2 = awsEnv();
  fs.writeFileSync(path.join(e2.home, 'identity.json'), JSON.stringify({ Account: '123456789012' }));
  assert.equal(checkOf(e2, 'identity').pass, false, 'typed by hand, never ran the command');
});

t('make-bucket: the right name in us-east-1 only; a differently named bucket or another region is rejected', () => {
  const e = awsEnv();
  e.setState({ buckets: { 'my-bucket': { tags: [], versioning: '' } }, volumes: [] });
  assert.equal(checkOf(e, 'make-bucket').pass, false, 'wrong name');
  e.setState({ buckets: { [BUCKET]: { tags: [], versioning: '' } }, volumes: [] });
  assert.equal(checkOf(e, 'make-bucket').pass, true);
  const other = checkOf(e, 'make-bucket', { AWS_REGION: 'eu-west-1' });
  assert.equal(other.pass, false);
  assert.match(other.message, /us-east-1/);
});

t('tag-bucket: the exact tag is required; other tags, a wrong value or no tags are rejected', () => {
  const e = awsEnv();
  const set = (tags) => e.setState({ buckets: { [BUCKET]: { tags, versioning: '' } }, volumes: [] });
  set([]); assert.equal(checkOf(e, 'tag-bucket').pass, false, 'no tags');
  set([{ Key: 'owner', Value: 'me' }]); assert.equal(checkOf(e, 'tag-bucket').pass, false, 'a different tag');
  set([{ Key: 'tws-labs', Value: 'wrong' }]); assert.equal(checkOf(e, 'tag-bucket').pass, false, 'wrong value');
  set([{ Key: 'owner', Value: 'me' }, { Key: 'tws-labs', Value: 'aws-cli-first-steps' }]); assert.equal(checkOf(e, 'tag-bucket').pass, true, 'extra tags are fine');
});

t('versioning: Enabled passes; Suspended and never-configured do not', () => {
  const e = awsEnv();
  const set = (v) => e.setState({ buckets: { [BUCKET]: { tags: [], versioning: v } }, volumes: [] });
  set(''); assert.equal(checkOf(e, 'versioning').pass, false);
  set('Suspended'); assert.equal(checkOf(e, 'versioning').pass, false);
  set('Enabled'); assert.equal(checkOf(e, 'versioning').pass, true);
});

t('read-status: needs --query, the get command, and a file holding only the word', () => {
  const e = awsEnv();
  const file = path.join(e.home, 'status.txt');
  e.typed('aws s3api get-bucket-versioning --bucket x --query Status --output text > status.txt');
  fs.writeFileSync(file, '{\n    "Status": "Enabled"\n}\n');
  assert.equal(checkOf(e, 'read-status').pass, false, 'raw JSON');
  fs.writeFileSync(file, '"Enabled"\n');
  assert.equal(checkOf(e, 'read-status').pass, false, 'quotes kept');
  fs.writeFileSync(file, 'Enabled\n');
  assert.equal(checkOf(e, 'read-status').pass, true);
  const noQuery = awsEnv();
  fs.writeFileSync(path.join(noQuery.home, 'status.txt'), 'Enabled\n');
  noQuery.typed('aws s3api get-bucket-versioning --bucket x --output text | tr -d "{}" > status.txt');
  const nq = checkOf(noQuery, 'read-status');
  assert.equal(nq.pass, false, 'another flag with -- is not --query');
  assert.match(nq.message, /--query/);
  const e2 = awsEnv();
  fs.writeFileSync(path.join(e2.home, 'status.txt'), 'Enabled\n');
  e2.typed('echo Enabled > status.txt');
  assert.equal(checkOf(e2, 'read-status').pass, false, 'typed the answer instead of asking AWS');
});

t('cleanup: passes only once the bucket is gone', () => {
  const e = awsEnv();
  e.setState({ buckets: { [BUCKET]: { tags: [], versioning: '' } }, volumes: [] });
  assert.equal(checkOf(e, 'cleanup').pass, false);
  e.setState({ buckets: {}, volumes: [] });
  assert.equal(checkOf(e, 'cleanup').pass, false, 'a bucket that never existed (nothing was created or deleted) is not a cleanup');
  e.typed(`aws s3api delete-bucket --bucket ${BUCKET}`);
  assert.equal(checkOf(e, 'cleanup').pass, true);
});
