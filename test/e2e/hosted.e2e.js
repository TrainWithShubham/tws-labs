// The hosted profile and the ways a session can end, in a real browser: invite code, seat cap, idle and time-limit ends,
// two tabs, a closed tab freeing its seat, and a server restart. Needs the two servers from docker-compose.hosted.yml
// (BASE_HOSTED and BASE_HOSTED_CAP); skipped when they are not running.
const test = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const B = require('./browser');

const SKIP = !B.HOSTED && 'set BASE_HOSTED (docker compose -f test/e2e/docker-compose.hosted.yml up -d --wait)';
const CODE = 'e2e-code';
const TRACK = 'linux-fundamentals';
const LAB = 'files';
const t = (name, opts, fn) => (fn ? test(name, { skip: SKIP, timeout: 150000, ...opts }, fn) : test(name, { skip: SKIP, timeout: 150000 }, opts));

let browser;
test.before(async () => { if (!SKIP) browser = await B.launch(); });
test.after(async () => { if (browser) await browser.close(); });

const labUrl = (base = B.HOSTED) => `${base}/lab/${TRACK}/${LAB}`;
const seats = async (base = B.HOSTED) => (await (await fetch(`${base}/stats`)).json()).sessions;
async function waitSeats(n, base) { await B.waitFor(async () => (await seats(base)) === n, `${n} seat(s) in use`, 15000); }
const flat = async (page) => (await B.terminalText(page)).replace(/\n/g, ' ').replace(/\s+/g, ' ');
const pill = (page) => page.$eval('#status-pill', (e) => e.textContent.trim());
async function openHosted(opts = {}, base = B.HOSTED) {
  const page = await B.newPage(browser, { isolated: true, invite: opts.invite === undefined ? CODE : opts.invite, ...opts });
  await page.goto(labUrl(base), { waitUntil: 'networkidle2' });
  return page;
}
async function waitPromptIn(page) { await B.waitFor(async () => /learner@lab/.test(await B.terminalText(page)), 'a shell prompt', 30000); await B.sleep(200); }

t('invite code: the terminal waits for a code, a wrong code is refused kindly, the right one starts the lab and is remembered', async () => {
  const page = await openHosted({ invite: '' });
  try {
    await B.waitFor(async () => !(await B.isHidden(page, '#invite')), 'the invite form');
    assert.ok(await B.isHidden(page, '#term'), 'no terminal and no seat before a code is given');
    assert.equal(await seats(), 0, 'asking for a code takes no seat');
    await B.shot(page, 'hosted-invite');
    await page.type('#invite-code', 'not-the-code'); await page.keyboard.press('Enter');
    await B.waitFor(async () => /not accepted/.test(await page.$eval('#invite-msg', (e) => e.textContent)), 'the refusal message');
    assert.equal(await seats(), 0, 'a wrong code takes no seat');
    await page.type('#invite-code', CODE); await page.keyboard.press('Enter');
    await waitPromptIn(page);
    assert.equal(await pill(page), 'live');
    await page.reload({ waitUntil: 'networkidle2' });
    await waitPromptIn(page);                                    // remembered: no form the second time
    assert.ok(await B.isHidden(page, '#invite'));
  } finally { await B.closePage(page); }
});

t('an account lab is a read-only walkthrough on the hosted site: no terminal, no seat, a way to run it locally', async () => {
  const page = await B.newPage(browser, { isolated: true });
  try {
    await page.goto(`${B.HOSTED}/lab/aws/aws-cli-first-steps`, { waitUntil: 'networkidle2' });
    assert.match(await page.$eval('body', (e) => e.innerText), /runs on your machine/);
    assert.match(await page.$eval('body', (e) => e.innerText), /AWS=1 \.\/start_local_labs\.sh/);
    assert.equal((await page.$$('#term')).length, 0);
    assert.equal(await seats(), 0);
    await B.shot(page, 'hosted-account-lab');
  } finally { await B.closePage(page); }
});

t('seat cap: a third learner is told the seats are taken, waits, and gets in when a seat frees up', async () => {
  const a = await openHosted(); const b = await openHosted();
  let c;
  try {
    await waitPromptIn(a); await waitPromptIn(b);
    assert.equal(await seats(), 2);
    c = await openHosted();
    await B.waitFor(async () => /seats on this server are taken/.test(await flat(c)), 'the busy message');
    assert.equal(await pill(c), 'waiting');
    assert.match(await flat(c), /Retrying in a few seconds/);
    await B.shot(c, 'hosted-busy');
    await B.closePage(a);                                        // a seat frees up
    await B.waitFor(async () => /learner@lab/.test(await B.terminalText(c)), 'the waiting learner to get in', 45000);
    assert.equal(await pill(c), 'live');
  } finally { for (const p of [a, b, c]) if (p) await B.closePage(p); }
});

t('closing a tab frees its seat quickly', async () => {
  const before = await seats();
  const page = await openHosted();
  await waitPromptIn(page);
  assert.equal(await seats(), before + 1);
  await B.closePage(page);
  await waitSeats(before);
});

t('idle end: the learner is told in plain words, the pill says ended, and Restart lab brings the terminal back', async () => {
  const page = await openHosted();
  try {
    await waitPromptIn(page);
    await B.waitFor(async () => /idle for too long/.test(await flat(page)), 'the idle message', 25000);
    assert.equal(await pill(page), 'ended');
    assert.match(await B.hintText(page), /idle for too long.*Restart lab/);
    assert.equal(await page.$eval('#lab-timer-text', (e) => e.textContent), '--:--', 'no stale countdown after the session ended');
    await B.shot(page, 'hosted-idle-ended');
    await page.click('#restart-btn'); await page.click('#restart-btn');
    await B.waitFor(async () => /Fresh start/.test(await B.terminalText(page)), 'the fresh start', 30000);
    await waitPromptIn(page);
    assert.equal(await pill(page), 'live');
  } finally { await B.closePage(page); }
});

t('time limit: the countdown reaches zero and the session ends with an explanation', { skip: !B.HOSTED_CAP && 'set BASE_HOSTED_CAP' }, async () => {
  const page = await openHosted({}, B.HOSTED_CAP);
  try {
    await waitPromptIn(page);
    await B.waitFor(async () => /time limit/.test(await flat(page)), 'the time-limit message', 40000);
    assert.equal(await pill(page), 'ended');
    await B.waitFor(async () => (await page.$eval('#lab-timer-text', (e) => e.textContent)) === '00:00', 'the timer at 00:00', 10000);
  } finally { await B.closePage(page); }
});

t('two tabs on one lab are two separate sandboxes, and closing one leaves the other working', async () => {
  const one = await openHosted(); const two = await openHosted();
  try {
    await waitPromptIn(one); await waitPromptIn(two);
    await B.clickAction(one);                                    // lesson -> mkdir task, in tab one only
    await B.typeLine(one, 'mkdir workspace');
    await B.clickAction(one);
    assert.equal(await one.$eval('#step-hint', (e) => e.classList.contains('is-ok')), true, 'tab one passes');
    await B.clickAction(two); await B.clickAction(two);          // the same Check in tab two
    assert.equal(await two.$eval('#step-hint', (e) => e.classList.contains('is-ok')), false, 'tab two has its own empty home');
    await B.closePage(one);
    await B.typeLine(two, 'echo still-here');
    assert.match(await B.terminalText(two), /still-here/);
  } finally { await B.closePage(one); await B.closePage(two); }
});

t('a server restart is explained to the learner, and Restart lab recovers once the server is back', { skip: !process.env.E2E_HOSTED_CONTAINER && 'set E2E_HOSTED_CONTAINER (the hosted container name)' }, async () => {
  const page = await openHosted();
  try {
    await waitPromptIn(page);
    const r = spawnSync('docker', ['restart', process.env.E2E_HOSTED_CONTAINER], { encoding: 'utf8' });
    assert.equal(r.status, 0, r.stderr);
    await B.waitFor(async () => /connection was lost/.test(await flat(page)), 'the connection-lost message', 30000);
    assert.equal(await pill(page), 'ended');
    assert.match(await B.hintText(page), /Restart lab/);
    await B.waitFor(async () => { try { return (await fetch(`${B.HOSTED}/healthz`)).ok; } catch { return false; } }, 'the server to come back', 40000);
    await page.click('#restart-btn'); await page.click('#restart-btn');
    await B.waitFor(async () => /Fresh start/.test(await B.terminalText(page)), 'the fresh start', 40000);
    await waitPromptIn(page);
    assert.equal(await pill(page), 'live');
  } finally { await B.closePage(page); }
});
