// public/progress.js runs in the browser; these tests load it into a stubbed window with an in-memory localStorage.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const SRC = fs.readFileSync(path.join(__dirname, '..', '..', 'public', 'progress.js'), 'utf8');

function load({ store = {}, broken = false, nodes = {} } = {}) {
  const localStorage = broken
    ? { getItem() { throw new Error('blocked'); }, setItem() { throw new Error('blocked'); } }
    : { getItem: (k) => (k in store ? store[k] : null), setItem: (k, v) => { store[k] = String(v); } };
  const document = { querySelectorAll: (sel) => nodes[sel] || [] };
  const window = {};
  vm.runInNewContext(SRC, { window, document, localStorage, JSON, Array });
  const raw = window.twsTasksDone;
  window.twsTasksDone = (lab) => Array.from(raw(lab));   // arrays made inside the vm are another realm's; copy them out
  return { window, store };
}
const node = (attrs) => ({
  attrs, textContent: '', classList: { add() {} }, style: { setProperty() {} },
  getAttribute(k) { return this.attrs[k]; }, closest: () => null,
});

test('a passed task is remembered per lab, once', () => {
  const { window, store } = load();
  window.twsMarkTask('git-basics/gitignore', 'create-rules');
  window.twsMarkTask('git-basics/gitignore', 'create-rules');
  window.twsMarkTask('git-basics/gitignore', 'check-ignore');
  window.twsMarkTask('docker/dockerfile-craft', 'build');
  assert.deepEqual(window.twsTasksDone('git-basics/gitignore'), ['create-rules', 'check-ignore']);
  assert.deepEqual(window.twsTasksDone('docker/dockerfile-craft'), ['build']);
  assert.deepEqual(window.twsTasksDone('nothing/here'), []);
  assert.ok(JSON.parse(store['tws-local:tasks']), 'stored as JSON under its own key');
});

test('remembered tasks survive a page reload', () => {
  const first = load();
  first.window.twsMarkTask('a/b', 'one');
  const second = load({ store: first.store });
  assert.deepEqual(second.window.twsTasksDone('a/b'), ['one']);
});

test('blocked or corrupt storage never throws and reads as nothing done', () => {
  const blocked = load({ broken: true });
  blocked.window.twsMarkTask('a/b', 'one');
  assert.deepEqual(blocked.window.twsTasksDone('a/b'), []);
  const corrupt = load({ store: { 'tws-local:tasks': '{not json' } });
  assert.deepEqual(corrupt.window.twsTasksDone('a/b'), []);
  corrupt.window.twsMarkTask('a/b', 'one');
  assert.deepEqual(corrupt.window.twsTasksDone('a/b'), ['one'], 'a bad value is replaced, not fatal');
  const wrongShape = load({ store: { 'tws-local:tasks': '{"a/b":"oops"}' } });
  assert.deepEqual(wrongShape.window.twsTasksDone('a/b'), []);
});

test('the summary shows only partial progress, as "n of m tasks"', () => {
  const { window } = load();
  assert.equal(window.twsTaskSummary('a/b', 5), '', 'nothing done yet');
  window.twsMarkTask('a/b', 'one'); window.twsMarkTask('a/b', 'two'); window.twsMarkTask('a/b', 'three');
  assert.equal(window.twsTaskSummary('a/b', 5), '3 of 5 tasks');
  window.twsMarkTask('a/b', 'four'); window.twsMarkTask('a/b', 'five');
  assert.equal(window.twsTaskSummary('a/b', 5), '', 'a fully done lab shows the lab-done mark, not a count');
  window.twsMarkTask('a/b', 'stale-removed-task');
  assert.equal(window.twsTaskSummary('a/b', 5), '', 'never more than the total');
});

test('a track page fills each lab row with its partial count', () => {
  const store = { 'tws-local:tasks': JSON.stringify({ 'git-basics/gitignore': ['x', 'y'] }) };
  const slot = node({ 'data-lab-tasks': 'git-basics/gitignore', 'data-total': '5' });
  const other = node({ 'data-lab-tasks': 'git-basics/undoing', 'data-total': '4' });
  load({ store, nodes: { '[data-lab-tasks]': [slot, other] } });
  assert.equal(slot.textContent, ' · 2 of 5 tasks');
  assert.equal(other.textContent, '');
});

test('finished labs still work as before', () => {
  const { window, store } = load();
  window.twsMarkDone('a/b');
  assert.deepEqual(JSON.parse(store['tws-local:done']), ['a/b']);
});

test('hints: appear only after a failed check, one tier at a time, from gentle to specific', () => {
  const { window } = load();
  const h = window.twsHints();
  const tiers = ['nudge', 'closer', 'almost there'];
  assert.equal(h.ready('do', tiers), false, 'not before the learner has tried');
  h.failed('do');
  assert.deepEqual({ ...h.ready('do', tiers) }, { label: 'Need a hint?' });
  assert.equal(h.next('do', tiers), 'Hint 1 of 3: nudge');
  assert.deepEqual({ ...h.ready('do', tiers) }, { label: 'Another hint' });
  assert.equal(h.next('do', tiers), 'Hint 2 of 3: closer');
  assert.equal(h.next('do', tiers), 'Hint 3 of 3: almost there');
  assert.equal(h.ready('do', tiers), false, 'nothing left to reveal');
  assert.equal(h.next('do', tiers), null);
  assert.equal(h.shown('do', tiers), 'Hint 3 of 3: almost there', 'the last revealed hint can be shown again');
});

test('hints: a single hint reads without "1 of 1"; no hints means no button; steps are independent', () => {
  const { window } = load();
  const h = window.twsHints();
  h.failed('a'); h.failed('b');
  assert.equal(h.ready('a', []), false);
  assert.equal(h.next('a', ['only']), 'Hint: only');
  assert.equal(h.ready('a', ['only']), false);
  assert.notEqual(h.ready('b', ['x', 'y']), false, 'step b is untouched by step a');
  assert.equal(h.shown('b', ['x', 'y']), '');
});

test('two-step confirm: the first click arms, a second within the window confirms, and it then disarms', () => {
  const { window } = load();
  let now = 1000;
  const confirm = window.twsTwoStep(4000, () => now);
  assert.equal(confirm(), false, 'first click only arms');
  now += 1500;
  assert.equal(confirm(), true, 'second click inside the window confirms');
  assert.equal(confirm(), false, 'and it is armed again from scratch');
  now += 4001;
  assert.equal(confirm(), false, 'too slow: this click re-arms instead of confirming');
  now += 100;
  assert.equal(confirm(), true);
});

test('pending input: text left on the prompt line is found, so a failed Check can say "press Enter"', () => {
  const { window } = load();
  const p = (line) => window.twsPendingInput(line);
  assert.equal(p('learner@lab:~$ aws sts get-caller-identity > identity.json'), 'aws sts get-caller-identity > identity.json');
  assert.equal(p('learner@lab:~/workspace$ ls -la   '), 'ls -la');
  assert.equal(p('learner@lab:~$ '), '', 'an empty prompt');
  assert.equal(p('learner@lab:~$'), '');
  assert.equal(p('{'), '', 'program output is not a prompt');
  assert.equal(p('"Account": "123456789012",'), '');
  assert.equal(p(''), '');
  assert.equal(p(undefined), '');
  assert.equal(p('root@host:/# echo hi'), 'echo hi', 'a # prompt works too');
  assert.equal(p('learner@lab:~$ echo "cost: $5"'), 'echo "cost: $5"', 'a dollar sign inside the command is not the prompt');
});

test('end-of-session messages: plain words for every way a session can end, never a bare close code', () => {
  const { window } = load();
  const m = (code, reason) => window.twsEndMessage(code, reason);
  assert.match(m(4000, 'idle timeout'), /idle/i);
  assert.match(m(4000, 'session time limit reached'), /time limit/i);
  assert.match(m(1000, 'shell exited'), /exit/i);
  assert.match(m(1000, 'ended by learner'), /ended/i);
  assert.match(m(4001, 'invalid or expired session'), /expired|no longer valid/i);
  assert.match(m(4002, 'session already connected'), /another tab/i);
  assert.match(m(1011, 'could not start the lab sandbox'), /could not start/i);
  assert.match(m(1006, ''), /connection (was )?lost|dropped/i);
  assert.match(m(1001, ''), /connection (was )?lost|dropped|closed/i);
  for (const code of [1006, 1001, 4000, 1000, 4999]) assert.match(m(code, ''), /Restart lab|reload/i, `${code} tells the learner what to do next`);
  assert.ok(!/undefined|\[object/.test(m(undefined, undefined)));
});

test('terminal messages are wrapped at word boundaries to the terminal width, never in the middle of a word', () => {
  const { window } = load();
  const w = (s, n) => Array.from(window.twsWrap(s, n));
  assert.deepEqual(w('one two three four five', 10), ['one two', 'three four', 'five']);
  assert.deepEqual(w('short', 80), ['short']);
  assert.deepEqual(w('', 80), ['']);
  assert.deepEqual(w('a verylongwordthatcannotfit here', 8), ['a', 'verylongwordthatcannotfit', 'here'], 'a word longer than the width stays whole on its own line');
  for (const line of w('All lab seats on this server are taken right now. A seat usually frees up within a few minutes. Retrying in a few seconds…', 40)) assert.ok(line.length <= 40, line);
  assert.deepEqual(w('x', 0), ['x'], 'a nonsense width falls back to no wrapping');
});

test('skipping ahead: a task that ships setup is prepared once, only when an earlier task is not done yet', () => {
  const { window } = load();
  const steps = [{ id: 'intro', type: 'lesson' }, { id: 'a', type: 'task', setup: false }, { id: 'b', type: 'task', setup: true }, { id: 'c', type: 'task', setup: true }];
  const need = (done, i, prepared) => window.twsNeedsPrep(steps, done, i, prepared || {});
  assert.equal(need({}, 2), true, 'b has setup and task a is not done');
  assert.equal(need({ a: true }, 2), false, 'nothing was skipped');
  assert.equal(need({}, 1), false, 'a ships no setup');
  assert.equal(need({}, 0), false, 'a lesson never needs it');
  assert.equal(need({}, 3), true);
  assert.equal(need({ a: true, b: true }, 3), false);
  assert.equal(need({}, 2, { b: true }), false, 'already prepared in this session');
  assert.equal(need({ intro: true }, 2), true, 'lessons do not count as skipped tasks');
});

test('skipping to a task that builds on an earlier one: the learner is told once, plainly', () => {
  const { window } = load();
  const steps = [{ id: 'a', type: 'task' }, { id: 'b', type: 'task', skipNote: 'it needs the file from the step before' }];
  assert.equal(window.twsSkipNote(steps, {}, 1, {}), 'This task builds on an earlier one: it needs the file from the step before.');
  assert.equal(window.twsSkipNote(steps, { a: true }, 1, {}), '', 'nothing was skipped');
  assert.equal(window.twsSkipNote(steps, {}, 0, {}), '');
  assert.equal(window.twsSkipNote(steps, {}, 1, { b: true }), '', 'only once');
});
