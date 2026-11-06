const test = require('node:test');
const assert = require('node:assert/strict');
const { createUi, esc, rocket } = require('../../src/ui');
const { assertBrandedPage } = require('../assert-branded');

const site = { channel: { name: 'C', url: 'https://www.youtube.com/@x' }, videos: [] };

test('esc escapes markup and quotes', () => {
  assert.equal(esc('<a href="x">&'), '&lt;a href=&quot;x&quot;&gt;&amp;');
});

test('every page built by ui.page has the branded header, with the right active tab and env chip', () => {
  const ui = createUi({ chip: 'cluster', chipTitle: 'pod-1' });
  const names = { labs: 'Labs', challenges: 'Challenges', videos: 'Videos', roadmap: 'Roadmap' };
  for (const a of Object.keys(names)) {
    const html = ui.page({ active: a, site }, 'X', '<main></main>');
    assertBrandedPage(html, names[a], a);
    assert.match(html, /<span class="mono chip-env" title="pod-1">cluster<\/span>/);
  }
});

test('the frame defines the rocket once, links a favicon, and escapes titles and chip text', () => {
  const html = createUi({ chip: '<x>' }).page({ active: 'labs', site }, '<script>', '');
  assert.equal((html.match(/<symbol id="rocket"/g) || []).length, 1);
  assert.match(html, /<link rel="icon" href="data:image\/svg\+xml,/);
  assert.ok(!html.includes('<script>') && !html.includes('<x>'));
  assert.match(rocket('big'), /<svg class="rk big" aria-hidden="true" focusable="false"><use href="#rocket"\/><\/svg>/);
});

test('page() takes extra head tags after the shared stylesheet', () => {
  const html = createUi({ chip: 'local' }).page({ active: 'labs', site }, 'T', '', '', '<link rel="stylesheet" href="/x.css" />');
  assert.ok(html.indexOf('/app.css') > -1 && html.indexOf('/app.css') < html.indexOf('/x.css'));
});

test('serveAsset serves the stylesheets, scripts and logo; optional font import; ignores other paths', () => {
  const sent = [];
  const res = { writeHead: (s, h) => sent.push([s, h['Content-Type']]), end: () => {} };
  const ui = createUi({ chip: 'local' });
  const served = ['/app.css', '/lab.js', '/progress.js', '/home.css', '/home.js', '/roadmap.css', '/roadmap.js', '/logo/tws-labs-logo.png'];
  for (const p of served) assert.equal(ui.serveAsset({ method: 'GET' }, res, p), true, p);
  assert.equal(ui.serveAsset({ method: 'GET' }, res, '/etc/passwd'), false);
  assert.equal(ui.serveAsset({ method: 'GET' }, res, '/../package.json'), false);
  assert.equal(ui.serveAsset({ method: 'POST' }, res, '/app.css'), false);
  assert.ok(sent.every(([status]) => status === 200));
  let body = '';
  const grab = { writeHead() {}, end: (d) => { body = d.toString(); } };
  createUi({ chip: 'c', remoteFonts: true }).serveAsset({ method: 'GET' }, grab, '/app.css');
  assert.match(body, /@import url\('https:\/\/fonts\.googleapis\.com/);
  createUi({ chip: 'c' }).serveAsset({ method: 'GET' }, grab, '/app.css');
  assert.ok(!body.includes('googleapis'), 'offline by default');
});
