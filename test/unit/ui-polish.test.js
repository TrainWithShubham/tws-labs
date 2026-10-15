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
