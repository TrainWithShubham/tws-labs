// Guards for the cosmetic defects a real browser showed: wrapped button labels, literal markdown characters in lab text.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { loadCatalog } = require('../../src/loader');

const PUBLIC = path.join(__dirname, '..', '..', 'public');
const LABS = path.join(__dirname, '..', '..', 'labs');
const css = (f) => fs.readFileSync(path.join(PUBLIC, f), 'utf8');

test('buttons never wrap their labels, and the step footer wraps whole buttons instead', () => {
  assert.match(css('components.css'), /\.btn\s*\{[^}]*white-space:\s*nowrap/);
  assert.match(css('lab.css'), /\.step-footer\s*\{[^}]*flex-wrap:\s*wrap/);
});

test('no lab text shows literal emphasis characters: *word* or _word_ outside code', () => {
  const bad = [];
  for (const track of loadCatalog(LABS).tracks) {
    for (const lab of track.labs) {
      const texts = [lab.summary, ...lab.steps.flatMap((s) => [s.bodyHtml, s.localBodyHtml || '', s.success, ...(s.hints || [])])];
      for (const t of texts) {
        const plain = String(t || '').replace(/<pre>[\s\S]*?<\/pre>/g, '').replace(/<code>[\s\S]*?<\/code>/g, '');
        const m = plain.match(/(^|[\s(])[*_][A-Za-z][^*_<]*[A-Za-z][*_](?=[\s.,;:)!?]|$)/);
        if (m) bad.push(`${track.id}/${lab.id}: ${m[0].trim()}`);
      }
    }
  }
  assert.deepEqual(bad, []);
});

// --- accessibility guards that need no browser ---
const lum = (hex) => {
  const [r, g, b] = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255).map((c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4));
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
};
const ratio = (a, b) => { const [hi, lo] = [lum(a), lum(b)].sort((x, y) => y - x); return (hi + 0.05) / (lo + 0.05); };
const token = (name) => {
  const m = css('tokens.css').match(new RegExp(`--${name}:\\s*#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})\\b`));
  assert.ok(m, `--${name} is a plain hex colour in tokens.css`);
  return '#' + (m[1].length === 3 ? [...m[1]].map((c) => c + c).join('') : m[1]);
};

test('every text colour token meets WCAG AA (4.5:1) on every background token', () => {
  const bad = [];
  for (const fg of ['text', 'muted', 'faint', 'ok', 'bad', 'devops', 'cloud', 'ai']) {
    for (const bg of ['bg', 'panel', 'panel2']) {
      const r = ratio(token(fg), token(bg));
      if (r < 4.5) bad.push(`--${fg} on --${bg} is ${r.toFixed(2)}:1`);
    }
  }
  assert.deepEqual(bad, []);
});

test('keyboard focus is always visible, and every page has a skip link to the main content', () => {
  assert.match(css('components.css'), /:focus-visible\s*\{[^}]*outline:/, 'a shared :focus-visible outline');
  const { createUi } = require('../../src/ui');
  const ui = createUi({ chip: 'local', xtermDir: path.join(PUBLIC, '..', 'node_modules', '@xterm') });
  const html = ui.page({ active: 'labs', site: { channel: { url: 'https://example.com' } } }, 'T', '<p>body</p>');
  assert.match(html, /<a class="skip" href="#main">Skip to content<\/a>/);
  assert.match(html, /<main id="main"[^>]*><p>body<\/p><\/main>/);
});
