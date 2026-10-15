const test = require('node:test');
const assert = require('node:assert/strict');
const { judge } = require('../../scripts/check-image-size');

const MB = 1024 * 1024;

test('an image at or under the budget passes and reports its headroom', () => {
  const r = judge(700 * MB, 800);
  assert.equal(r.ok, true);
  assert.equal(r.sizeMb, 700);
  assert.equal(r.headroomMb, 100);
  assert.equal(judge(800 * MB, 800).ok, true, 'exactly the budget is fine');
});

test('an image over the budget fails and says by how much', () => {
  const r = judge(823 * MB, 800);
  assert.equal(r.ok, false);
  assert.equal(r.headroomMb, -23);
  assert.match(r.message, /23 MB over/);
  assert.match(r.message, /image-size-budget\.json/);
});

test('a missing or nonsensical size or budget is an error, never a silent pass', () => {
  assert.throws(() => judge(NaN, 800), /image size/);
  assert.throws(() => judge(0, 800), /image size/);
  assert.throws(() => judge(700 * MB, 0), /budget/);
  assert.throws(() => judge(700 * MB, undefined), /budget/);
});
