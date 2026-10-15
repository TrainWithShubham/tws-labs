// A two-lab catalog for the account-lab tests: cloud/acct needs AWS, cloud/plain does not.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

function awsLabsDir() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'awslabs-'));
  fs.chmodSync(root, 0o755);   // in the image each session runs as its own user, which must be able to read the checks
  fs.copyFileSync(path.join(__dirname, '..', '..', 'labs', 'lib.sh'), path.join(root, 'lib.sh'));
  fs.mkdirSync(path.join(root, 'cloud'));
  fs.writeFileSync(path.join(root, 'cloud', 'track.yaml'), 'title: Cloud\ndescription: d\nlabs: [acct, plain]\n');
  for (const [id, requires] of [['acct', 'requires: aws\n'], ['plain', '']]) {
    const d = path.join(root, 'cloud', id);
    fs.mkdirSync(path.join(d, 'checks'), { recursive: true });
    fs.mkdirSync(path.join(d, 'solutions'), { recursive: true });
    fs.writeFileSync(path.join(d, 'lab.yaml'), `${requires}title: ${id}\nlevel: beginner\nminutes: 10\nsummary: s\nsteps:\n  - {id: intro, type: lesson, title: Intro, body: "Use **your own** account."}\n  - {id: show, type: task, title: Show it, body: do it, hint: "a nudge here"}\n`);
    fs.writeFileSync(path.join(d, 'checks', 'show.sh'), '. "$LAB_LIB"\n[ "$AWS_REGION" = "us-east-1" ] || fail "no region"\n');
    fs.writeFileSync(path.join(d, 'solutions', 'show.sh'), 'true\n');
  }
  return root;
}

module.exports = { awsLabsDir };

// A tiny lab for the skip-ahead tests: task "use" needs proj/ from task "make", and ships setup/use.sh (with a cwd line).
function skipLabsDir() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'skiplabs-'));
  fs.chmodSync(root, 0o755);
  fs.copyFileSync(path.join(__dirname, '..', '..', 'labs', 'lib.sh'), path.join(root, 'lib.sh'));
  const d = path.join(root, 's', 'skip');
  for (const sub of ['checks', 'solutions', 'setup']) fs.mkdirSync(path.join(d, sub), { recursive: true });
  fs.writeFileSync(path.join(root, 's', 'track.yaml'), 'title: S\ndescription: d\nlabs: [skip]\n');
  fs.writeFileSync(path.join(d, 'lab.yaml'), 'title: Skip\nlevel: beginner\nminutes: 10\nsummary: s\nsteps:\n  - {id: intro, type: lesson, title: Intro, body: hi}\n  - {id: make, type: task, title: Make, body: "Make proj.", hint: "a nudge for you"}\n  - {id: use, type: task, title: Use, body: "Put data.txt in proj.", hint: "another nudge"}\n  - {id: solo, type: task, title: Solo, body: "No setup here.", hint: "yet another nudge"}\n');
  fs.writeFileSync(path.join(d, 'checks', 'make.sh'), '. "$LAB_LIB"\n[ -d proj ] || fail "no proj"\n');
  fs.writeFileSync(path.join(d, 'checks', 'use.sh'), '. "$LAB_LIB"\n[ -f proj/data.txt ] || fail "no data.txt"\n');
  fs.writeFileSync(path.join(d, 'checks', 'solo.sh'), '. "$LAB_LIB"\n[ -f solo.txt ] || fail "no solo.txt"\n');
  fs.writeFileSync(path.join(d, 'solutions', 'make.sh'), 'mkdir proj\n');
  fs.writeFileSync(path.join(d, 'solutions', 'use.sh'), 'echo x > data.txt\n');
  fs.writeFileSync(path.join(d, 'solutions', 'solo.sh'), 'touch solo.txt\n');
  fs.writeFileSync(path.join(d, 'setup', 'use.sh'), '#!/bin/bash\n# cwd: proj\nmkdir -p proj\n');
  return root;
}
module.exports.skipLabsDir = skipLabsDir;
