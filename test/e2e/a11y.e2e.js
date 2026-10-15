// Accessibility in a real browser: axe-core on every kind of page (WCAG 2 A and AA plus best practice), and keyboard-only reachability.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const B = require('./browser');

const AXE = fs.readFileSync(path.join(__dirname, '..', '..', 'node_modules', 'axe-core', 'axe.min.js'), 'utf8');
const PAGES = [
  ['home', '/'],
  ['roadmap', '/roadmap'],
  ['videos', '/videos'],
  ['track', '/t/linux-fundamentals'],
  ['lab', '/lab/linux-fundamentals/files'],
  ['not-found', '/no-such-page'],
];
let browser;
test.before(async () => { browser = await B.launch(); });
test.after(async () => { if (browser) await browser.close(); });

async function audit(page) {
  await page.evaluate(AXE);
  // The terminal (xterm) is a canvas-like widget with its own helper elements; it is covered by the keyboard test below, not by axe.
  return page.evaluate(async () => {
    const r = await axe.run({ exclude: [['.xterm']] }, { runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'best-practice'] } });
    return r.violations.map((v) => ({ id: v.id, impact: v.impact, help: v.help, nodes: v.nodes.slice(0, 3).map((n) => n.target.join(' ')) }));
  });
}

for (const [name, url] of PAGES) {
  test(`axe: ${name} has no serious or critical accessibility violations`, async () => {
    const page = await B.newPage(browser);
    try {
      await page.goto(B.BASE + url, { waitUntil: 'networkidle2' });
      if (name === 'lab') await B.waitFor(async () => /learner@lab/.test(await B.terminalText(page)), 'the terminal');
      await B.sleep(400);   // let the entrance fade finish so contrast is measured on the settled page
      const violations = await audit(page);
      const bad = violations.filter((v) => v.impact === 'serious' || v.impact === 'critical');
      assert.deepEqual(bad, [], `${name}: ${JSON.stringify(bad, null, 1)}`);
      const rest = violations.filter((v) => v.impact !== 'serious' && v.impact !== 'critical');
      if (rest.length) console.log(`  note (${name}): ${rest.map((v) => `${v.id}(${v.impact})`).join(', ')}`);
    } finally { await page.close(); }
  });
}

test('keyboard only: a skip link comes first, focus is clearly visible, and the terminal is not a keyboard trap', async () => {
  const page = await B.newPage(browser);
  try {
    await page.goto(`${B.BASE}/t/linux-fundamentals`, { waitUntil: 'networkidle2' });
    await page.keyboard.press('Tab');
    const first = await page.evaluate(() => ({ cls: document.activeElement.className, top: document.activeElement.getBoundingClientRect().top }));
    assert.equal(first.cls, 'skip', 'the first Tab stop is the skip link');
    assert.ok(first.top >= 0, 'and it is on screen when focused');
    // on a lab page, every interactive control reached with the keyboard shows a ring
    await B.openLab(page, 'linux-fundamentals', 'files');
    await page.evaluate(() => document.querySelector('.skip').focus());
    const rings = [];
    for (let i = 0; i < 14; i++) {
      await page.keyboard.press('Tab');
      rings.push(await page.evaluate(() => { const e = document.activeElement; const s = getComputedStyle(e); return { who: e.id || e.className || e.tagName, style: s.outlineStyle, width: parseFloat(s.outlineWidth) }; }));
    }
    const noRing = rings.filter((r) => r.style === 'none' || r.width === 0);
    assert.deepEqual(noRing, [], 'every control reached by Tab has a visible focus ring');
    // inside the terminal, Shift+Tab leaves it
    await page.click('.xterm');
    await page.keyboard.down('Shift'); await page.keyboard.press('Tab'); await page.keyboard.up('Shift');
    assert.equal(await page.evaluate(() => !!document.activeElement.closest('.xterm')), false, 'Shift+Tab moves focus out of the terminal');
  } finally { await page.close(); }
});
