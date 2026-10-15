const test = require('node:test');
const assert = require('node:assert/strict');
const { createRouter } = require('../../src/router');

const req = (method) => ({ method });
const url = (p) => new URL(p, 'http://localhost');

test('routes match on method and exact path, and report whether they handled the request', () => {
  const r = createRouter();
  const seen = [];
  r.get('/a', () => seen.push('get a'));
  r.post('/a', () => seen.push('post a'));
  assert.equal(r.handle(req('GET'), {}, url('/a')), true);
  assert.equal(r.handle(req('POST'), {}, url('/a')), true);
  assert.equal(r.handle(req('GET'), {}, url('/b')), false, 'unknown path');
  assert.equal(r.handle(req('DELETE'), {}, url('/a')), false, 'unknown method');
  assert.deepEqual(seen, ['get a', 'post a']);
});

test('a regex route hands its captures to the handler', () => {
  const r = createRouter();
  let got;
  r.get(/^\/lab\/([a-z0-9-]+)\/([a-z0-9-]+)$/, (_req, _res, c) => { got = [c.m[1], c.m[2], c.p]; });
  assert.equal(r.handle(req('GET'), {}, url('/lab/git-basics/gitignore')), true);
  assert.deepEqual(got, ['git-basics', 'gitignore', '/lab/git-basics/gitignore']);
  assert.equal(r.handle(req('GET'), {}, url('/lab/Bad/x')), false);
});

test('the first matching route wins, in the order they were added', () => {
  const r = createRouter();
  const seen = [];
  r.get('/x', () => seen.push('first'));
  r.get('/x', () => seen.push('second'));
  r.handle(req('GET'), {}, url('/x'));
  assert.deepEqual(seen, ['first']);
});

test('use() slots a function into the same order; returning true means it handled the request', () => {
  const r = createRouter();
  const seen = [];
  r.get('/early', () => seen.push('early'));
  r.use((_req, _res, p) => { seen.push('use:' + p); return p === '/asset.css'; });
  r.get('/late', () => seen.push('late'));
  assert.equal(r.handle(req('GET'), {}, url('/asset.css')), true);
  assert.equal(r.handle(req('GET'), {}, url('/late')), true);
  assert.equal(r.handle(req('GET'), {}, url('/nothing')), false);
  assert.deepEqual(seen, ['use:/asset.css', 'use:/late', 'late', 'use:/nothing']);
});

test('the query string never affects matching', () => {
  const r = createRouter();
  let hit = false;
  r.get('/session/remaining', (_req, _res, c) => { hit = c.url.searchParams.get('token') === 'abc'; });
  assert.equal(r.handle(req('GET'), {}, url('/session/remaining?token=abc')), true);
  assert.ok(hit);
});
