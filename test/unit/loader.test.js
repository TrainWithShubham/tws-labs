const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { loadCatalog } = require('../../src/loader');

function fixture(files) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'loader-'));
  for (const [rel, content] of Object.entries(files)) {
    fs.mkdirSync(path.dirname(path.join(dir, rel)), { recursive: true });
    fs.writeFileSync(path.join(dir, rel), content);
  }
  return dir;
}

const GOOD_LAB = `title: T
level: beginner
steps:
  - {id: a, type: lesson, title: A, body: hi}
  - {id: b, type: task, title: B, body: do it, hint: nudge}
`;
const TRACK = 'title: Track\ndescription: d\nlabs: [one]\n';

test('a well-formed track/lab loads with rendered steps', () => {
  const dir = fixture({ 't/track.yaml': TRACK, 't/one/lab.yaml': GOOD_LAB, 't/one/checks/b.sh': 'true', 't/one/solutions/b.sh': 'true' });
  const c = loadCatalog(dir);
  assert.deepEqual(c.problems, []);
  assert.equal(c.tracks[0].labs[0].steps[1].hint, 'nudge');
  assert.equal(c.tracks[0].labs[0].steps[0].bodyHtml, '<p>hi</p>');
});

test('a task without a check script or solution is reported, and the lab is skipped', () => {
  const dir = fixture({ 't/track.yaml': TRACK, 't/one/lab.yaml': GOOD_LAB });
  const c = loadCatalog(dir);
  assert.match(c.problems.join('\n'), /missing checks\/b\.sh/);
  assert.equal(c.tracks[0].labs.length, 0);
});

test('bad ids, duplicate ids, bad level and path-traversal ids are rejected', () => {
  const bad = (labYaml, re) => {
    const dir = fixture({ 't/track.yaml': TRACK, 't/one/lab.yaml': labYaml });
    assert.match(loadCatalog(dir).problems.join('\n'), re);
  };
  bad(GOOD_LAB.replace('level: beginner', 'level: wizard'), /level must be/);
  bad(GOOD_LAB.replace('id: b', 'id: a'), /duplicate id/);
  bad(GOOD_LAB.replace('id: b', 'id: ../../etc'), /id must match/);
  const dir = fixture({ 't/track.yaml': 'title: x\nlabs: ["../escape"]\n' });
  assert.match(loadCatalog(dir).problems.join('\n'), /bad lab id/);
});

test('malformed YAML is a reported problem, not a crash', () => {
  const dir = fixture({ 't/track.yaml': TRACK, 't/one/lab.yaml': 'title: [unclosed' });
  assert.ok(loadCatalog(dir).problems.length > 0);
});

test('the shipped labs/ directory has no problems', () => {
  assert.deepEqual(loadCatalog(path.join(__dirname, '..', '..', 'labs')).problems, []);
});

test('track video must be an https URL with a title', () => {
  const mk = (video) => fixture({ 't/track.yaml': TRACK + video, 't/one/lab.yaml': GOOD_LAB, 't/one/checks/b.sh': 'true', 't/one/solutions/b.sh': 'true' });
  assert.deepEqual(loadCatalog(mk('video: {title: V, url: "https://youtu.be/x"}\n')).problems, []);
  assert.match(loadCatalog(mk('video: {title: V, url: "javascript:alert(1)"}\n')).problems.join(), /https/);
  assert.match(loadCatalog(mk('video: {url: "https://youtu.be/x"}\n')).problems.join(), /video needs/);
});

test('an optional success message is kept, and a too-long or non-text one is rejected', () => {
  const files = { 't/track.yaml': TRACK, 't/one/checks/b.sh': 'true', 't/one/solutions/b.sh': 'true' };
  const ok = loadCatalog(fixture({ ...files, 't/one/lab.yaml': GOOD_LAB.replace('hint: nudge}', 'hint: nudge, success: "Layer reused"}') }));
  assert.deepEqual(ok.problems, []);
  assert.equal(ok.tracks[0].labs[0].steps[1].success, 'Layer reused');
  assert.equal(ok.tracks[0].labs[0].steps[0].success, '');
  const long = loadCatalog(fixture({ ...files, 't/one/lab.yaml': GOOD_LAB.replace('hint: nudge}', `hint: nudge, success: "${'x'.repeat(101)}"}`) }));
  assert.match(long.problems.join('\n'), /success must be text/);
});

test('a hint can be one nudge or a list of up to three, from gentle to specific; the first stays as `hint`', () => {
  const files = { 't/track.yaml': TRACK, 't/one/checks/b.sh': 'true', 't/one/solutions/b.sh': 'true' };
  const load = (hint) => loadCatalog(fixture({ ...files, 't/one/lab.yaml': GOOD_LAB.replace('hint: nudge}', `hint: ${hint}}`) }));
  const one = load('nudge').tracks[0].labs[0].steps[1];
  assert.deepEqual([one.hint, one.hints], ['nudge', ['nudge']]);
  const three = load('["Think about listing", "Look at ls flags", "ls -la shows hidden files"]');
  assert.deepEqual(three.problems, []);
  const s = three.tracks[0].labs[0].steps[1];
  assert.equal(s.hint, 'Think about listing');
  assert.deepEqual(s.hints, ['Think about listing', 'Look at ls flags', 'ls -la shows hidden files']);
  const none = loadCatalog(fixture({ ...files, 't/one/lab.yaml': GOOD_LAB.replace(', hint: nudge', '') })).tracks[0].labs[0].steps[1];
  assert.deepEqual([none.hint, none.hints], ['', []]);
});

test('a malformed hint list is reported: too many tiers, blank or non-text tiers, an overlong tier', () => {
  const files = { 't/track.yaml': TRACK, 't/one/checks/b.sh': 'true', 't/one/solutions/b.sh': 'true' };
  const problems = (hint) => loadCatalog(fixture({ ...files, 't/one/lab.yaml': GOOD_LAB.replace('hint: nudge}', `hint: ${hint}}`) })).problems.join('\n');
  assert.match(problems('[a, b, c, d]'), /hint: at most 3 tiers/);
  assert.match(problems('["a", ""]'), /hint: every tier must be non-empty text/);
  assert.match(problems('["a", 5]'), /hint: every tier must be non-empty text/);
  assert.match(problems(`"${'x'.repeat(301)}"`), /hint: each tier is at most 300 characters/);
  assert.match(problems('{a: 1}'), /hint: must be text or a list of text/);
});
