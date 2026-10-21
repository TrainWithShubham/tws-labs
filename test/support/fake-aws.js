#!/usr/bin/env node
// A TEST DOUBLE for the AWS CLI, used only by unit tests of lab checks and helpers. It is not shipped in the image and not a
// simulator for learners: it answers just the calls the checks make, from a JSON state file in $FAKE_AWS_DIR.
//   FAKE_AWS_ARN / FAKE_AWS_ACCOUNT / FAKE_AWS_DOWN=1 (every call fails like missing credentials)
const fs = require('fs');
const path = require('path');

const dir = process.env.FAKE_AWS_DIR;
const file = path.join(dir, 'state.json');
const load = () => (fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : { buckets: {}, volumes: [] });
const save = (s) => fs.writeFileSync(file, JSON.stringify(s));
fs.appendFileSync(path.join(dir, 'calls.log'), process.argv.slice(2).join(' ') + '\n');

const argv = process.argv.slice(2);
const opt = (name) => { const i = argv.indexOf(name); return i >= 0 ? argv[i + 1] : undefined; };
const ACCOUNT = process.env.FAKE_AWS_ACCOUNT || '123456789012';
const ARN = process.env.FAKE_AWS_ARN || `arn:aws:sts::${ACCOUNT}:assumed-role/tws-labs-learner/tws-labs`;
const die = (code, msg) => { console.error(`\nAn error occurred (${code}) when calling the operation: ${msg}`); process.exit(254); };
const out = (value) => {
  const q = opt('--query');
  let v = value;
  if (q) {
    const m = q.match(/^([A-Za-z]+)\[\]\.([A-Za-z]+)$/);
    if (m) v = (value[m[1]] || []).map((x) => x[m[2]]);
    else if (/^[A-Za-z.]+$/.test(q)) v = q.split('.').reduce((o, k) => (o == null ? o : o[k]), value);
  }
  if (opt('--output') === 'text') {
    console.log(Array.isArray(v) ? v.join('\t') : (v === null || v === undefined ? 'None' : (typeof v === 'object' ? JSON.stringify(v) : v)));
  } else console.log(JSON.stringify(v, null, 4));
};

if (process.env.FAKE_AWS_DOWN === '1') die('NoCredentials', 'Unable to locate credentials');
const [svc, op] = argv;
if (process.env.FAKE_AWS_FAIL_OP && process.env.FAKE_AWS_FAIL_OP === op) die('AccessDenied', 'User is not authorized to perform this operation');   // a call that fails while the identity call works
const s = load();
const bucket = opt('--bucket');
if (svc === 'sts' && op === 'get-caller-identity') out({ UserId: 'AROAEXAMPLE:tws-labs', Account: ACCOUNT, Arn: ARN });
else if (svc === 's3api' && op === 'list-buckets') out({ Buckets: Object.keys(s.buckets).map((Name) => ({ Name })) });
else if (svc === 's3api' && op === 'create-bucket') {
  if (s.buckets[bucket]) die('BucketAlreadyOwnedByYou', 'Your previous request to create the named bucket succeeded and you already own it.');
  s.buckets[bucket] = { tags: [], versioning: '' }; save(s); out({ Location: `/${bucket}` });
} else if (svc === 's3api' && op === 'head-bucket') { if (!s.buckets[bucket]) die('404', 'Not Found'); }
else if (svc === 's3api' && op === 'delete-bucket') { if (!s.buckets[bucket]) die('NoSuchBucket', 'The specified bucket does not exist'); delete s.buckets[bucket]; save(s); }
else if (svc === 's3api' && op === 'put-bucket-tagging') {
  if (!s.buckets[bucket]) die('NoSuchBucket', 'The specified bucket does not exist');
  const raw = opt('--tagging');
  const tags = raw.trim().startsWith('{') ? JSON.parse(raw).TagSet
    : [...raw.matchAll(/\{Key=([^,}]+),Value=([^}]*)\}/g)].map((m) => ({ Key: m[1], Value: m[2] }));   // the CLI's shorthand: TagSet=[{Key=k,Value=v}]
  if (!tags.length) die('MalformedXML', 'The XML you provided was not well-formed or did not validate against our published schema');
  s.buckets[bucket].tags = tags; save(s);
} else if (svc === 's3api' && op === 'get-bucket-tagging') {
  if (!s.buckets[bucket]) die('NoSuchBucket', 'The specified bucket does not exist');
  if (!s.buckets[bucket].tags.length) die('NoSuchTagSet', 'The TagSet does not exist');
  out({ TagSet: s.buckets[bucket].tags });
} else if (svc === 's3api' && op === 'put-bucket-versioning') {
  if (!s.buckets[bucket]) die('NoSuchBucket', 'The specified bucket does not exist');
  s.buckets[bucket].versioning = /Status=(\w+)/.exec(opt('--versioning-configuration'))[1]; save(s);
} else if (svc === 's3api' && op === 'get-bucket-versioning') {
  if (!s.buckets[bucket]) die('NoSuchBucket', 'The specified bucket does not exist');
  out(s.buckets[bucket].versioning ? { Status: s.buckets[bucket].versioning } : {});
} else if (svc === 'ec2' && op === 'describe-volumes') out({ Volumes: s.volumes });
else if (svc === 'ec2' && op === 'delete-volume') { s.volumes = s.volumes.filter((v) => v.VolumeId !== opt('--volume-id')); save(s); }
else die('UnsupportedInFake', `fake aws does not implement: ${argv.join(' ')}`);
