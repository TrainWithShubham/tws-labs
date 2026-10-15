const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { loadCases } = require('../../src/cases');

function labDir(files) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cases-'));
  for (const [rel, text] of Object.entries(files)) {
    fs.mkdirSync(path.dirname(path.join(dir, rel)), { recursive: true });
    fs.writeFileSync(path.join(dir, rel), text);
  }
  return dir;
}

test('no cases directory means no cases and no problems', () => {
  assert.deepEqual(loadCases(labDir({ 'lab.yaml': 'x' }), ['mkdir']), { cases: [], problems: [] });
});

test('a case named ok-* must pass the check, any other must fail it, and each is tied to its task', () => {
  const dir = labDir({ 'cases/mkdir/wrong-name.sh': 'mkdir wrokspace\n', 'cases/mkdir/ok-nested.sh': 'mkdir -p workspace/a\n', 'cases/touch/empty-path.sh': 'touch hello.txt\n' });
  const { cases, problems } = loadCases(dir, ['mkdir', 'touch']);
  assert.deepEqual(problems, []);
  assert.deepEqual(cases.map((c) => [c.task, c.name, c.expect]), [
    ['mkdir', 'ok-nested', 'pass'], ['mkdir', 'wrong-name', 'fail'], ['touch', 'empty-path', 'fail'],
  ]);
  assert.equal(path.basename(cases[0].file), 'ok-nested.sh');
  assert.deepEqual(cases[1].lines, ['mkdir wrokspace']);
});

test('lines are one command each: comments and blanks are dropped', () => {
  const dir = labDir({ 'cases/mkdir/x.sh': '# a wrong guess\n\nmkdir  a \n' });
  assert.deepEqual(loadCases(dir, ['mkdir']).cases[0].lines, ['mkdir  a']);
});

test('a case for a task that does not exist, or for a lesson, is reported', () => {
  const dir = labDir({ 'cases/nope/x.sh': 'true\n' });
  assert.match(loadCases(dir, ['mkdir']).problems.join('\n'), /cases\/nope: no task called "nope"/);
});

test('cases follow the solutions\' rules: no heredocs or line continuations, and a case cannot be empty', () => {
  const dir = labDir({ 'cases/mkdir/heredoc.sh': 'cat > a <<EOF\nx\nEOF\n', 'cases/mkdir/cont.sh': 'mkdir \\\n a\n', 'cases/mkdir/empty.sh': '# nothing\n' });
  const p = loadCases(dir, ['mkdir']).problems.join('\n');
  assert.match(p, /cases\/mkdir\/heredoc\.sh: one command per line/);
  assert.match(p, /cases\/mkdir\/cont\.sh: one command per line/);
  assert.match(p, /cases\/mkdir\/empty\.sh: no commands/);
});

test('files that are not .sh are ignored, and names stay simple', () => {
  const dir = labDir({ 'cases/mkdir/notes.md': 'hello', 'cases/mkdir/Bad Name.sh': 'true\n' });
  const { cases, problems } = loadCases(dir, ['mkdir']);
  assert.deepEqual(cases, []);
  assert.match(problems.join('\n'), /Bad Name\.sh: case names use a-z, 0-9 and -/);
});
