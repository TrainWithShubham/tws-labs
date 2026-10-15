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
