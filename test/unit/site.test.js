const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { loadSite, httpsUrl } = require('../../src/site');

const write = (text) => { const f = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'site-')), 'site.yaml'); fs.writeFileSync(f, text); return f; };

test('the shipped labs/site.yaml is valid and points at the TrainWithShubham channel', () => {
  const s = loadSite();
  assert.deepEqual(s.problems, []);
  assert.match(s.channel.url, /^https:\/\/www\.youtube\.com\//);
});

test('site.yaml: https-only links, validated videos, a missing file is fine, a bad channel falls back', () => {
  assert.deepEqual(loadSite(path.join(os.tmpdir(), 'nope.yaml')).problems, []);
  const ok = loadSite(write('channel: {name: C, url: "https://y.com/c"}\nvideos:\n  - {title: V, url: "https://y.com/v"}\n'));
  assert.deepEqual(ok.problems, []);
  assert.equal(ok.videos.length, 1);
  const bad = loadSite(write('channel: {url: "http://y.com"}\nvideos:\n  - {title: V, url: "javascript:x"}\n'));
  assert.equal(bad.problems.length, 2);
  assert.equal(bad.channel.url, 'https://www.youtube.com/@TrainWithShubham');
  assert.ok(loadSite(write('title: [unclosed')).problems.length > 0);
});

test('httpsUrl accepts only https', () => {
  assert.equal(httpsUrl('https://a.b/c'), 'https://a.b/c');
  for (const u of ['http://a.b', 'javascript:alert(1)', 'ftp://a', '', undefined, '//a.b']) assert.equal(httpsUrl(u), null, String(u));
  for (const u of ['https://a.com/x"><img src=x onerror=alert(1)>', "https://a.com/x'y", 'https://a.com/x y', 'https://a.com/`x`']) assert.equal(httpsUrl(u), null, u);   // would break out of an href
});
