#!/usr/bin/env node
// Re-records docs/media/lab-demo.gif (the README demo) from the running app, so it always shows the real product.
//   ./start_local_labs.sh            (in another terminal; or: LABS_PORT=8097 docker compose -p demo up -d --build)
//   BASE=http://localhost:8080 node scripts/record-demo.js [out.gif]
// Needs Chrome (CHROME_PATH or a standard location), ffmpeg, and the dev dependencies (npm ci).
// The story: type a command but forget Enter -> Check says so -> Enter -> green; a miss -> tiered hints -> green; skip ahead -> the files
// the next task needs are set up for you -> green.
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');
const B = require('../test/e2e/browser');

const OUT = path.resolve(process.argv[2] || path.join(__dirname, '..', 'docs', 'media', 'lab-demo.gif'));
const WIDTH = 900;
const FPS = 10;

async function typeSlow(page, text, delay = 38) { await page.click('.xterm'); await page.keyboard.type(text, { delay }); }
async function click(page, sel) { await page.click(sel); }

(async () => {
  const browser = await B.launch();
  const page = await B.newPage(browser, { width: 1280, height: 720, isolated: true });
  const frames = [];
  let recording = false;
  const t0 = Date.now();
  const loop = (async () => {
    while (recording !== null) {
      if (recording) frames.push({ t: Date.now() - t0, buf: await page.screenshot({ type: 'png' }) });
      else await B.sleep(20);
    }
  })();
  const pause = (ms) => B.sleep(ms);
  try {
    await B.openLab(page, 'linux-fundamentals', 'files');
    recording = true;
    await pause(900);
    await click(page, '#action-btn'); await pause(1000);                       // lesson -> mkdir
    await typeSlow(page, 'mkdir workspace'); await pause(500);                  // typed, never submitted
    await click(page, '#action-btn'); await pause(2600);                        // amber: press Enter
    await page.keyboard.press('Enter'); await pause(700);
    await click(page, '#action-btn'); await pause(1700);                        // green
    await click(page, '#action-btn'); await pause(800);                         // Next -> touch
    await click(page, '#action-btn'); await pause(1100);                        // a miss
    await click(page, '#hint-btn'); await pause(1500);                          // hint 1
    await click(page, '#hint-btn'); await pause(1700);                          // hint 2
    await typeSlow(page, 'touch workspace/hello.txt'); await page.keyboard.press('Enter'); await pause(600);
    await click(page, '#action-btn'); await pause(1700);                        // green
    await click(page, '#action-btn'); await pause(800);                         // Next -> write
    await click(page, '#skip-btn'); await pause(500);                           // Skip -> cp: its files are set up for you
    await pause(2600);
    await typeSlow(page, 'cp workspace/hello.txt workspace/backup.txt'); await page.keyboard.press('Enter'); await pause(600);
    await click(page, '#action-btn'); await pause(2200);                        // green
  } finally {
    recording = null; await loop; await B.closePage(page); await browser.close();
  }

  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'demo-'));
  const list = [];
  frames.forEach((f, i) => {
    const name = `f${String(i).padStart(5, '0')}.png`;
    fs.writeFileSync(path.join(dir, name), f.buf);
    const next = i + 1 < frames.length ? frames[i + 1].t : f.t + 1500;
    list.push(`file '${name}'`, `duration ${((next - f.t) / 1000).toFixed(3)}`);
  });
  list.push(`file '${path.basename(`f${String(frames.length - 1).padStart(5, '0')}.png`)}'`);
  fs.writeFileSync(path.join(dir, 'list.txt'), list.join('\n') + '\n');
  const vf = `fps=${FPS},scale=${WIDTH}:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=96:stats_mode=diff[p];[b][p]paletteuse=dither=none`;
  const r = spawnSync('ffmpeg', ['-y', '-v', 'error', '-f', 'concat', '-safe', '0', '-i', path.join(dir, 'list.txt'), '-vf', vf, '-loop', '0', OUT], { encoding: 'utf8' });
  if (r.status !== 0) { console.error(r.stderr); process.exit(1); }
  console.log(`${frames.length} frames, ${((frames[frames.length - 1].t) / 1000).toFixed(1)} s -> ${OUT} (${(fs.statSync(OUT).size / 1024).toFixed(0)} KB)`);
})().catch((e) => { console.error(e); process.exit(1); });
