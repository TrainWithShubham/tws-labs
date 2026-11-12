// Emulator labs in a real browser: the page waits for the AWS Emulator, opens the terminal with the real `aws` CLI pointed at it, and every task
// can be done and graded. Needs the stack started with the emulator (`EMULATOR=1 ./start_local_labs.sh`); on a stack without it these tests skip.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const yaml = require('js-yaml');
const B = require('./browser');

const LABS = path.join(__dirname, '..', '..', 'labs');
// Every lab that says `requires: emulator`, found the same way CI finds them.
const EMULATOR_LABS = fs.readdirSync(LABS, { withFileTypes: true }).filter((d) => d.isDirectory()).flatMap((t) => (
  fs.readdirSync(path.join(LABS, t.name), { withFileTypes: true }).filter((d) => d.isDirectory())
    .filter((l) => fs.existsSync(path.join(LABS, t.name, l.name, 'lab.yaml')) && yaml.load(fs.readFileSync(path.join(LABS, t.name, l.name, 'lab.yaml'), 'utf8')).requires === 'emulator')
    .map((l) => [t.name, l.name])));
const labSpec = (track, lab) => yaml.load(fs.readFileSync(path.join(LABS, track, lab, 'lab.yaml'), 'utf8'));
const solution = (track, lab, step) => fs.readFileSync(path.join(LABS, track, lab, 'solutions', `${step}.sh`), 'utf8').split('\n').filter((l) => l.trim());

let browser;
let emulatorUp = false;
test.before(async () => {
  try { emulatorUp = !!(await (await fetch(`${B.BASE}/emulator/status`)).json()).ready; } catch { emulatorUp = false; }
  // CI sets E2E_REQUIRE_EMULATOR: there, a stack without the emulator is a broken job, not something to skip quietly.
  if (!emulatorUp && process.env.E2E_REQUIRE_EMULATOR) throw new Error(`the stack at ${B.BASE} has no AWS Emulator answering (E2E_REQUIRE_EMULATOR is set)`);
  if (emulatorUp) browser = await B.launch();
});
test.after(async () => { if (browser) await browser.close(); });

test('there are emulator labs to play', () => { assert.ok(EMULATOR_LABS.length >= 4, `found ${EMULATOR_LABS.length} emulator labs`); });

for (const [track, lab] of EMULATOR_LABS) {
  test(`${track}/${lab}: played through the UI, the CLI in the terminal reaches the emulator, each solution turns Check green, and the lab finishes`, async (t) => {
    if (!emulatorUp) return t.skip('the stack was not started with EMULATOR=1');
    const spec = labSpec(track, lab);
    const page = await B.newPage(browser, {});
    try {
      await page.goto(`${B.BASE}/lab/${track}/${lab}`, { waitUntil: 'networkidle2' });
      await B.waitFor(async () => /learner@lab/.test(await B.terminalText(page)), 'a shell prompt (the page waited for the emulator, then opened the terminal)', 60000);
      await B.sleep(300);
      await B.typeLine(page, 'aws sts get-caller-identity --query Account --output text');
      assert.match(await B.terminalText(page), /000000000000/, 'the real CLI inside the terminal talks to the emulator, with no flags or keys typed');
      await B.shot(page, `emulator-${lab}-terminal`);
      for (const [i, step] of spec.steps.entries()) {
        const isLast = i === spec.steps.length - 1;
        assert.match(await B.stepCounter(page), new RegExp(`Step ${i + 1} of ${spec.steps.length}`));
        if (step.type === 'task') {
          for (const line of solution(track, lab, step.id)) await B.typeLine(page, line);
          await B.clickAction(page);
          const hint = await page.$eval('#step-hint', (e) => ({ text: e.textContent.trim(), ok: e.classList.contains('is-ok') }));
          assert.ok(hint.ok, `step ${step.id} should turn green; the learner saw: "${hint.text}"`);
          await B.clickAction(page);   // Next
        } else if (!isLast) {
          await B.clickAction(page);
        } else {
          await B.clickAction(page);
          await page.click('#action-btn');
        }
      }
      await B.waitFor(async () => /Mission complete/.test(await page.$eval('#step-body', (e) => e.textContent)), 'the completion screen');
      await B.shot(page, `emulator-${lab}-complete`);
      assert.deepEqual(page.problems, [], 'no console error or failed request');
    } finally { await page.close(); }
  });
}

test('Check says what is wrong, in plain words, when the learner has not done the task yet', async (t) => {
  if (!emulatorUp) return t.skip('the stack was not started with EMULATOR=1');
  const page = await B.newPage(browser, {});
  try {
    const [track, lab] = EMULATOR_LABS[0];
    await B.openLab(page, track, lab);
    await B.clickAction(page);   // lesson -> first task
    await B.clickAction(page);   // Check with nothing done
    const text = await B.hintText(page);
    assert.ok(text.length > 10 && !(await page.$eval('#step-hint', (e) => e.classList.contains('is-ok'))), `a plain-words miss; the learner saw: "${text}"`);
    assert.doesNotMatch(text, /AWS_ENDPOINT_URL|emulator is not answering/, 'a normal miss is not an emulator problem');
    assert.deepEqual(page.problems, []);
  } finally { await page.close(); }
});
