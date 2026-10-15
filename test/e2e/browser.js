// Shared plumbing for the real-browser tests: launch Chrome, open a lab, type into the real xterm, click Check, read what the learner sees.
// These need a running stack (`./start_local_labs.sh`, or `docker compose up -d --build --wait`) and a Chrome; see `npm run e2e`.
const fs = require('node:fs');
const path = require('node:path');
const puppeteer = require('puppeteer-core');

const BASE = process.env.BASE || 'http://localhost:8080';
const SHOTS = process.env.SHOTS || path.join(__dirname, 'screenshots');
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function chromePath() {
  const candidates = [process.env.CHROME_PATH, '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', '/usr/bin/google-chrome', '/usr/bin/google-chrome-stable', '/usr/bin/chromium', '/usr/bin/chromium-browser'];
  const found = candidates.find((c) => c && fs.existsSync(c));
  if (!found) throw new Error('No Chrome found. Install Chrome or set CHROME_PATH.');
  return found;
}

async function launch() {
  const browser = await puppeteer.launch({ executablePath: chromePath(), headless: true, args: ['--no-sandbox', '--disable-dev-shm-usage'] });
  return browser;
}

// A page that records console errors and uncaught exceptions, so every flow can assert the learner never triggers one.
// isolated: its own browser profile (separate localStorage), like a different learner. invite: pre-fill the saved invite code.
async function newPage(browser, { width = 1440, height = 900, isolated = false, invite = '' } = {}) {
  const context = isolated ? await browser.createBrowserContext() : null;
  const page = await (context || browser).newPage();
  page.context_ = context;
  if (invite) await page.evaluateOnNewDocument((v) => { try { localStorage.setItem('tws:invite', v); } catch (e) { /* ignore */ } }, invite);
  await page.setViewport({ width, height });
  page.problems = [];
  page.on('pageerror', (e) => page.problems.push(`pageerror: ${e.message}`));
  page.on('console', (m) => { if (m.type() === 'error') page.problems.push(`console: ${m.text()}`); });
  page.on('requestfailed', (r) => { if (!/favicon|\/ws\?|fonts\.(googleapis|gstatic)\.com/.test(r.url())) page.problems.push(`request failed: ${r.url()}`); });
  return page;
}

async function closePage(page) { const c = page.context_; await page.close().catch(() => {}); if (c) await c.close().catch(() => {}); }

const terminalText = (page) => page.$eval('.xterm-rows', (e) => e.innerText).catch(() => '');

async function waitFor(fn, what, ms = 20000) {
  const t0 = Date.now();
  for (;;) {
    const v = await fn();
    if (v) return v;
    if (Date.now() - t0 > ms) throw new Error(`timed out waiting for ${what}`);
    await sleep(100);
  }
}

// The prompt is back and the screen has stopped changing: the last command has finished.
async function waitPrompt(page, ms = 20000) {
  let last = '';
  let stableSince = 0;
  return waitFor(async () => {
    const text = await terminalText(page);
    const lines = text.split('\n').map((l) => l.replace(/\s+$/, '')).filter(Boolean);
    const atPrompt = /learner@lab[^\n]*\$$/.test(lines[lines.length - 1] || '');
    if (text !== last) { last = text; stableSince = Date.now(); return false; }
    return atPrompt && Date.now() - stableSince > 300;
  }, 'the shell prompt', ms);
}

async function openLab(page, track, lab) {
  await page.goto(`${BASE}/lab/${track}/${lab}`, { waitUntil: 'networkidle2' });
  await waitFor(async () => /learner@lab/.test(await terminalText(page)), 'a shell prompt in the terminal', 30000);
  await sleep(300);
}

// Type into the real terminal one key at a time, like a learner, and press Enter.
async function typeLine(page, text, { enter = true } = {}) {
  await page.click('.xterm');
  await page.keyboard.type(text, { delay: 5 });
  if (enter) { await page.keyboard.press('Enter'); await waitPrompt(page); }
}

const stepCounter = (page) => page.$eval('#step-counter', (e) => e.textContent.trim());
const hintText = (page) => page.$eval('#step-hint', (e) => e.textContent.trim());
const actionLabel = (page) => page.$eval('#action-btn', (e) => e.textContent.trim());
const isHidden = (page, sel) => page.$eval(sel, (e) => e.hidden || getComputedStyle(e).display === 'none').catch(() => true);

// Click the primary button (Check / Got it / Next) and wait until it is usable again.
async function clickAction(page) {
  await page.click('#action-btn');
  await sleep(150);
  await waitFor(async () => !(await page.$eval('#action-btn', (e) => e.disabled)), 'the Check button to be ready again', 20000);
}

async function shot(page, name) {
  fs.mkdirSync(SHOTS, { recursive: true });
  await page.screenshot({ path: path.join(SHOTS, `${name}.png`) });
}

const HOSTED = process.env.BASE_HOSTED || '';
const HOSTED_CAP = process.env.BASE_HOSTED_CAP || '';
module.exports = { BASE, HOSTED, HOSTED_CAP, closePage, sleep, launch, newPage, openLab, typeLine, waitPrompt, waitFor, terminalText, stepCounter, hintText, actionLabel, isHidden, clickAction, shot };
