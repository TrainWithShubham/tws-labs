// What a learner does, in a real browser against the real stack. Assertions are on what is visible, not on internals.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const yaml = require('js-yaml');
const B = require('./browser');

const LABS = path.join(__dirname, '..', '..', 'labs');
const labYaml = (track, lab) => yaml.load(fs.readFileSync(path.join(LABS, track, lab, 'lab.yaml'), 'utf8'));
const solution = (track, lab, step) => fs.readFileSync(path.join(LABS, track, lab, 'solutions', `${step}.sh`), 'utf8').split('\n').filter((l) => l.trim());

let browser;
test.before(async () => { browser = await B.launch(); });
test.after(async () => { if (browser) await browser.close(); });

async function withPage(opts, fn) {
  const page = await B.newPage(browser, opts);
  try { await fn(page); } finally { await page.close(); }
}
const noProblems = (page) => assert.deepEqual(page.problems, [], 'the learner never triggers a console error or a failed request');

test('home, roadmap, a track and a lab are all reachable by clicking, with no errors', async () => {
  await withPage({}, async (page) => {
    await page.goto(B.BASE, { waitUntil: 'networkidle2' });
    assert.match(await page.title(), /TWS Labs/);
    assert.ok((await page.$$('a[href^="/t/"], a[href^="/lab/"]')).length > 0, 'the home map links to labs');
    await B.shot(page, 'home');
    await page.click('a.tab[href="/roadmap"]');
    await page.waitForSelector('.topic, details', { timeout: 10000 });
    assert.match(page.url(), /\/roadmap$/);
    await B.shot(page, 'roadmap');
    await page.goto(`${B.BASE}/t/linux-fundamentals`, { waitUntil: 'networkidle2' });
    assert.match(await page.$eval('h1', (e) => e.textContent), /Linux/);
    assert.match(await page.$eval('[data-track-progress]', (e) => e.textContent), /\d+ of \d+ done/);
    await page.click('ol.labs li a');
    await page.waitForSelector('#term', { timeout: 10000 });
    assert.match(page.url(), /\/lab\/linux-fundamentals\//);
    await B.shot(page, 'track-to-lab');
    noProblems(page);
  });
});

test('a whole lab, played through the UI: type each solution, Check goes green, the finish screen appears, and the track remembers it', async () => {
  const [track, lab] = ['linux-fundamentals', 'files'];
  const spec = labYaml(track, lab);
  await withPage({}, async (page) => {
    await page.evaluate(() => { try { localStorage.clear(); } catch (e) { /* ignore */ } }).catch(() => {});
    await B.openLab(page, track, lab);
    for (const [i, step] of spec.steps.entries()) {
      const isLast = i === spec.steps.length - 1;
      assert.match(await B.stepCounter(page), new RegExp(`Step ${i + 1} of ${spec.steps.length}`));
      if (step.type === 'task') {
        assert.equal(await B.actionLabel(page), 'Check');
        for (const line of solution(track, lab, step.id)) await B.typeLine(page, line);
        await B.clickAction(page);
        const hint = await page.$eval('#step-hint', (e) => ({ text: e.textContent.trim(), ok: e.classList.contains('is-ok') }));
        assert.ok(hint.ok, `step ${step.id} should turn green; the learner saw: "${hint.text}"`);
        assert.ok(hint.text.length > 0, 'the green confirmation has words');
        await B.clickAction(page);   // Next
      } else if (!isLast) {
        await B.clickAction(page);   // Got it
      } else {
        await B.clickAction(page);   // Got it on the last lesson, then Finish
        assert.equal(await B.actionLabel(page), 'Finish');
        await page.click('#action-btn');
      }
    }
    await B.waitFor(async () => /Mission complete/.test(await page.$eval('#step-body', (e) => e.textContent)), 'the completion screen');
    await B.shot(page, 'lab-complete');
    await page.goto(`${B.BASE}/t/${track}`, { waitUntil: 'networkidle2' });
    assert.match(await page.$eval('[data-track-progress]', (e) => e.textContent), /^[1-9]\d* of \d+ done/, 'the track page counts the finished lab');
    noProblems(page);
  });
});

test('hints come one tier at a time after a failed Check, Restart gives fresh files, and earlier passes are remembered', async () => {
  const [track, lab] = ['linux-fundamentals', 'files'];
  await withPage({}, async (page) => {
    await B.openLab(page, track, lab);
    await B.clickAction(page);                                    // lesson -> mkdir task
    assert.ok(await B.isHidden(page, '#hint-btn'), 'no hint button before the learner has tried');
    await B.clickAction(page);                                    // Check with nothing done: a miss
    assert.equal(await B.actionLabel(page), 'Check again');
    for (const line of solution(track, lab, 'mkdir')) await B.typeLine(page, line);
    await B.clickAction(page);
    await B.clickAction(page);                                    // Next -> touch task, which has three hint tiers
    assert.ok(await B.isHidden(page, '#hint-btn'));
    await B.clickAction(page);                                    // a miss on touch
    assert.equal(await page.$eval('#hint-btn', (e) => e.textContent.trim()), 'Need a hint?');
    await page.click('#hint-btn');
    assert.match(await B.hintText(page), /^Hint 1 of 3:/);
    assert.equal(await page.$eval('#hint-btn', (e) => e.textContent.trim()), 'Another hint');
    await page.click('#hint-btn'); assert.match(await B.hintText(page), /^Hint 2 of 3:/);
    await page.click('#hint-btn'); assert.match(await B.hintText(page), /^Hint 3 of 3:/);
    assert.ok(await B.isHidden(page, '#hint-btn'), 'nothing left to reveal');
    await B.shot(page, 'hints');

    // Restart: the second click confirms; the files are fresh and the lab starts over.
    await page.click('#restart-btn');
    assert.match(await page.$eval('#restart-btn', (e) => e.textContent), /Click again/);
    await page.click('#restart-btn');
    await B.waitFor(async () => /Fresh start/.test(await B.terminalText(page)), 'the fresh-start banner', 30000);
    await B.waitPrompt(page, 30000);
    assert.match(await B.stepCounter(page), /Step 1 of/);
    await B.clickAction(page);                                    // lesson -> mkdir
    await B.clickAction(page);                                    // Check
    assert.notEqual(await page.$eval('#step-hint', (e) => e.classList.contains('is-ok')), true, 'the workspace folder from before is gone');
    assert.match(await B.stepCounter(page), /done before/, 'the learner\'s earlier pass is remembered');
    noProblems(page);
  });
});

test('a command typed but not run is called out, focus returns to the terminal, and the buttons never wrap at any width', async () => {
  for (const [width, height] of [[1440, 900], [1024, 800], [390, 844]]) {
    await withPage({ width, height }, async (page) => {
      await B.openLab(page, 'linux-fundamentals', 'files');
      await B.clickAction(page);
      await B.typeLine(page, 'mkdir workspace', { enter: false });            // typed, not submitted
      await B.clickAction(page);
      assert.match(await B.hintText(page), /typed but not run yet\. Press Enter/);
      const heights = await page.$$eval('.step-footer .btn:not([hidden])', (els) => els.map((e) => ({ t: e.textContent.trim(), h: Math.round(e.getBoundingClientRect().height) })));
      for (const b of heights) assert.ok(b.h <= 46, `${width}px: "${b.t}" is ${b.h}px tall, so its label wrapped`);
      await B.shot(page, `nudge-${width}`);
      await page.keyboard.press('Enter');                                      // focus is already back in the terminal
      await B.waitPrompt(page);
      await B.clickAction(page);
      assert.equal(await page.$eval('#step-hint', (e) => e.classList.contains('is-ok')), true, 'after Enter the same Check passes');
      noProblems(page);
    });
  }
});

test('lab text shows emphasis as emphasis, never as literal asterisks', async () => {
  await withPage({}, async (page) => {
    await B.openLab(page, 'aws', 'aws-cli-first-steps');
    await B.clickAction(page);                                                  // intro -> identity task
    assert.equal(await page.$eval('#step-body em', (e) => e.textContent), 'as someone');
    assert.ok(!(await page.$eval('#step-body', (e) => e.textContent)).includes('*'));
    noProblems(page);
  });
});

test('Skip never dead-ends: skipping ahead sets up the files the next task needs, and says so', async () => {
  await withPage({}, async (page) => {
    // Linux files: skip "mkdir" and go straight to "touch workspace/hello.txt"
    await B.openLab(page, 'linux-fundamentals', 'files');
    await B.clickAction(page);                                      // lesson -> mkdir task
    await page.click('#skip-btn');                                  // skip mkdir -> touch task
    assert.match(await B.stepCounter(page), /Step 3 of/);
    await B.waitFor(async () => /skipped ahead/.test(await B.hintText(page)), 'the skipped-ahead note');
    await B.typeLine(page, 'touch workspace/hello.txt');
    await B.clickAction(page);
    assert.equal(await page.$eval('#step-hint', (e) => e.classList.contains('is-ok')), true, 'the task is solvable even though mkdir was skipped');
    noProblems(page);
  });
  await withPage({}, async (page) => {
    // Git first commit: skip init and enter; the shell is moved into the repo for the README task
    await B.openLab(page, 'git-basics', 'first-commit');
    await B.clickAction(page);                                      // lesson -> init
    await page.click('#skip-btn'); await page.click('#skip-btn');   // init, enter -> readme
    await B.waitFor(async () => /moved into myrepo/.test(await B.hintText(page)), 'the note that the shell moved');
    await B.waitFor(async () => /myrepo/.test(await B.terminalText(page)), 'the prompt inside myrepo');
    await B.typeLine(page, 'echo "# My project" > README.md');
    await B.clickAction(page);
    assert.equal(await page.$eval('#step-hint', (e) => e.classList.contains('is-ok')), true);
    await B.shot(page, 'skip-ahead-git');
    noProblems(page);
  });
});
