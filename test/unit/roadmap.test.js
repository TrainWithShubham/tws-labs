const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { loadRoadmap, onMap, later } = require('../../src/roadmap');
const { loadCatalog } = require('../../src/loader');

// A tiny in-memory catalog: two tracks, three labs.
const lab = (id) => ({ id, title: id, minutes: 8, level: 'beginner', steps: [] });
const CATALOG = { tracks: [
  { id: 'linux', title: 'Linux', labs: [lab('one'), lab('two')] },
  { id: 'git', title: 'Git', labs: [lab('commit')] },
], problems: [] };
const write = (obj) => { const f = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'rm-')), 'roadmap.json'); fs.writeFileSync(f, typeof obj === 'string' ? obj : JSON.stringify(obj)); return f; };
const GOOD = () => ({ domains: [
  { id: 'devops', title: 'DevOps', topics: [
    { id: 'linux', title: 'Linux', status: 'live', track: 'linux' },
    { id: 'git', title: 'Git', status: 'live', labs: ['git/commit'] },
    { id: 'docker', title: 'Docker', status: 'next', also: ['cloud'], relevance: 97, subtopics: ['a', 'b'] },
    { id: 'ansible', title: 'Ansible', status: 'later' } ] },
  { id: 'cloud', title: 'Cloud', topics: [] },
] });
const problemsOf = (obj) => loadRoadmap(CATALOG, write(obj)).problems;

test('a valid roadmap resolves labs, picks the right link target, and splits map vs later', () => {
  const r = loadRoadmap(CATALOG, write(GOOD()));
  assert.deepEqual(r.problems, []);
  const [linux, git, docker] = r.domains[0].topics;
  assert.equal(linux.labs.length, 2);
  assert.equal(linux.href, '/t/linux', 'several labs -> the track page');
  assert.equal(git.href, '/lab/git/commit', 'exactly one lab -> straight to it');
  assert.equal(docker.href, '', 'no labs, nothing to link');
  assert.deepEqual(docker.also, ['cloud']);
  assert.deepEqual(onMap(r.domains[0]).map((t) => t.id), ['linux', 'git', 'docker']);
  assert.deepEqual(later(r.domains[0]).map((t) => t.id), ['ansible']);
});

test('the catalog decides truth: "live" needs labs, and labs need a "live" topic', () => {
  const noLabs = GOOD(); noLabs.domains[0].topics[0] = { id: 'linux', title: 'Linux', status: 'live' };
  assert.match(problemsOf(noLabs).join('\n'), /linux: status is "live" but no lab is attached/);
  const dishonest = GOOD(); dishonest.domains[0].topics[2].labs = ['git/commit']; dishonest.domains[0].topics[1].status = 'live';
  assert.match(problemsOf(dishonest).join('\n'), /docker: has labs attached but status is "next"/);
});

test('a lab nothing points to is reported, so no lab can be invisible', () => {
  const g = GOOD(); g.domains[0].topics[0] = { id: 'linux', title: 'Linux', status: 'live', labs: ['linux/one'] };
  assert.match(problemsOf(g).join('\n'), /lab "linux\/two" is not on the roadmap/);
});

test('bad references and values are reported and skipped, never thrown', () => {
  const g = GOOD();
  g.domains[0].topics.push(
    { id: 'x1', title: 'X', status: 'soonish' },
    { id: 'x2', title: 'X', status: 'next', relevance: 140 },
    { id: 'x3', title: 'X', status: 'next', video: { title: 'v', url: 'javascript:alert(1)' } },
    { id: 'x4', title: 'X', status: 'live', track: 'nope' },
    { id: 'x5', title: 'X', status: 'live', labs: ['linux/missing'] },
    { id: 'linux', title: 'Dup', status: 'next' },
    { id: 'Bad Id', title: 'X', status: 'next' });
  const text = problemsOf(g).join('\n');
  for (const re of [/status must be one of/, /relevance must be 0-100/, /video needs a title and an https/, /unknown track "nope"/, /unknown lab "linux\/missing"/, /duplicate topic id/, /needs an id and a title/]) assert.match(text, re);
  const r = loadRoadmap(CATALOG, write(g));
  assert.deepEqual(r.domains[0].topics.map((t) => t.id), ['linux', 'git', 'docker', 'ansible'], 'only valid topics survive');
});

test('interchanges must name a real, different line; broken files do not crash', () => {
  const g = GOOD(); g.domains[0].topics[2].also = ['cloud', 'nowhere', 'devops'];
  assert.deepEqual(loadRoadmap(CATALOG, write(g)).domains[0].topics[2].also, ['cloud']);
  assert.match(problemsOf('{not json').join(), /roadmap\.json/);
  assert.match(loadRoadmap(CATALOG, path.join(os.tmpdir(), 'missing-roadmap.json')).problems.join(), /file not found/);
  assert.match(problemsOf({ domains: [] }).join(), /domains\[\] is required/);
});

test('the shipped roadmap is valid against the shipped labs, and every line has something live or next', () => {
  const catalog = loadCatalog(path.join(__dirname, '..', '..', 'labs'));
  const r = loadRoadmap(catalog);
  assert.deepEqual(r.problems, []);
  assert.deepEqual(r.domains.map((d) => d.id), ['devops', 'cloud', 'ai']);
  for (const d of r.domains) assert.ok(onMap(d).length >= 3 && onMap(d).length <= 7, `${d.id} keeps the home map calm (3-7 stations)`);
  const live = r.domains.flatMap((d) => d.topics).filter((t) => t.status === 'live');
  assert.equal(live.reduce((n, t) => n + t.labs.length, 0), catalog.tracks.reduce((n, t) => n + t.labs.length, 0), 'every lab is on the map exactly once');
});

test('the shipped roadmap names no cloud provider or vendor products we decided to leave out', () => {
  const text = fs.readFileSync(path.join(__dirname, '..', '..', 'labs', 'roadmap.json'), 'utf8');
  assert.ok(!/azure|splunk|jira|slack|udaan|josh/i.test(text));
});
