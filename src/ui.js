// The TWS Labs shell: the header (logo, tabs, Subscribe), the page frame with the rocket sprite and favicon,
// and the table of static assets. Every page is built through page(), so the chrome is identical everywhere.
const fs = require('fs');
const path = require('path');

function esc(s) {
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

const TABS = [['labs', '/', 'Labs'], ['videos', '/videos', 'Videos'], ['roadmap', '/roadmap', 'Roadmap']];
const YT_ICON = '<svg viewBox="0 0 24 24" width="16" height="16" aria-hidden="true"><path fill="currentColor" d="M21.6 7.2a2.5 2.5 0 0 0-1.8-1.8C18.3 5 12 5 12 5s-6.3 0-7.8.4A2.5 2.5 0 0 0 2.4 7.2C2 8.7 2 12 2 12s0 3.3.4 4.8a2.5 2.5 0 0 0 1.8 1.8C5.7 19 12 19 12 19s6.3 0 7.8-.4a2.5 2.5 0 0 0 1.8-1.8C22 15.3 22 12 22 12s0-3.3-.4-4.8zM10 15V9l5.2 3z"/></svg>';
const FONTS_IMPORT = "@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&family=JetBrains+Mono:wght@400;500&display=swap');\n";
const PUBLIC = path.join(__dirname, '..', 'public');

// The TWS monogram rocket, traced from the brand artwork: swept-back body with a flat nose corner, round window, two separated
// fins and an amber flame. It keeps the monogram's own orientation (nose to the upper right). Defined once per page and reused
// with <use href="#rocket">. Colour comes from currentColor (body) and --flame (exhaust); the window shows the page behind it.
const ROCKET_PATHS = '<path d="M226 346 L405 167 C430 140 455 132 480 132 L575 132 L575 232 C575 262 562 285 545 302 L365 482 C350 410 300 352 226 346 Z" fill="currentColor"/>'
  + '<path d="M138 335 L208 262 Q222 254 240 254 L295 254 L224 326 Q185 322 138 335 Z" fill="currentColor"/>'
  + '<path d="M367 494 L453 410 L453 470 Q453 482 443 492 L373 570 L372 520 Q370 505 367 494 Z" fill="currentColor"/>'
  + '<circle cx="421" cy="287" r="48" fill="var(--rk-window,#000)"/>'
  + '<path d="M236 427 L284 474 C270 505 230 525 180 532 C185 490 205 455 236 427 Z" fill="var(--flame,#ffc978)"/>';
const SPRITE = `<svg width="0" height="0" style="position:absolute" aria-hidden="true" focusable="false"><symbol id="rocket" viewBox="130 120 460 460">${ROCKET_PATHS}</symbol></svg>`;
const FAVICON = 'data:image/svg+xml,' + encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="130 120 460 460">${ROCKET_PATHS.replace(/var\(--rk-window,#000\)/, '#000').replace(/var\(--flame,#ffc978\)/, '#ffc978').replace(/currentColor/g, '#7b52c3')}</svg>`);
const rocket = (cls = '') => `<svg class="rk ${cls}" aria-hidden="true" focusable="false"><use href="#rocket"/></svg>`;

const ext = (url, label) => `<a href="${esc(url)}" target="_blank" rel="noopener noreferrer">${label}</a>`;

/**
 * @param {object} o
 * @param {string} o.chip           env label in the header: 'local' | 'cluster'
 * @param {string} [o.chipTitle]    tooltip for the chip (e.g. the pod hostname)
 * @param {boolean} [o.remoteFonts] load Google Fonts (hosted app). Local stays offline.
 * @param {string} [o.xtermDir]     path to node_modules/@xterm, to serve /xterm/*
 */
function createUi(o) {
  const read = (...p) => fs.readFileSync(path.join(PUBLIC, ...p), 'utf8');
  const appCss = (o.remoteFonts ? FONTS_IMPORT : '') + read('tokens.css') + read('components.css') + read('lab.css');
  const assets = {
    '/app.css': () => [Buffer.from(appCss), 'text/css'],
    '/lab.js': () => [fs.readFileSync(path.join(PUBLIC, 'lab.js')), 'application/javascript'],
    '/progress.js': () => [fs.readFileSync(path.join(PUBLIC, 'progress.js')), 'application/javascript'],
    '/home.css': () => [fs.readFileSync(path.join(PUBLIC, 'home.css')), 'text/css'],
    '/roadmap.css': () => [fs.readFileSync(path.join(PUBLIC, 'roadmap.css')), 'text/css'],
    '/roadmap.js': () => [fs.readFileSync(path.join(PUBLIC, 'roadmap.js')), 'application/javascript'],
    '/home.js': () => [fs.readFileSync(path.join(PUBLIC, 'home.js')), 'application/javascript'],
    '/logo/tws-labs-logo.png': () => [fs.readFileSync(path.join(PUBLIC, 'logo', 'tws-labs-logo.png')), 'image/png'],
  };
  if (o.xtermDir) {
    const files = {
      '/xterm/xterm.js': [['xterm', 'lib', 'xterm.js'], 'application/javascript'],
      '/xterm/xterm.css': [['xterm', 'css', 'xterm.css'], 'text/css'],
      '/xterm/addon-fit.js': [['addon-fit', 'lib', 'addon-fit.js'], 'application/javascript'],
    };
    for (const [url, [parts, type]] of Object.entries(files)) assets[url] = () => [fs.readFileSync(path.join(o.xtermDir, ...parts)), type];
  }

  // Returns true when it served something. Apps call this first in their request handler.
  function serveAsset(req, res, pathname) {
    if (req.method !== 'GET' || !assets[pathname]) return false;
    try {
      const [data, type] = assets[pathname]();
      res.writeHead(200, { 'Content-Type': type, 'Cache-Control': 'no-cache' });
      res.end(data);
    } catch {
      res.writeHead(404);
      res.end('not found');
    }
    return true;
  }

  function topbar(ctx) {
    const tabs = TABS.map(([id, href, label]) =>
      `<a href="${href}" class="tab${id === ctx.active ? ' is-active' : ''}"${id === ctx.active ? ' aria-current="page"' : ''}>${label}</a>`).join('');
    return `<header class="topbar">
  <a class="logo" href="/"><img class="logo-mark" src="/logo/tws-labs-logo.png" alt="" />
    <span class="logo-word">TWS <span class="accent">Labs</span></span></a>
  <nav class="tabs" aria-label="Main">${tabs}</nav>
  <div class="topbar-right"><span class="mono chip-env"${o.chipTitle ? ` title="${esc(o.chipTitle)}"` : ''}>${esc(o.chip)}</span>
    <a class="btn-yt" href="${esc(ctx.site.channel.url)}" target="_blank" rel="noopener noreferrer">${YT_ICON} Subscribe</a></div>
</header>`;
  }

  // `head` adds page-specific tags (e.g. an extra stylesheet) after the shared /app.css.
  function page(ctx, title, body, scripts = '', head = '') {
    const css = '<link rel="stylesheet" href="/app.css" />';
    return `<!doctype html>
<html lang="en"><head><meta charset="utf-8" /><title>${esc(title)} · TWS Labs</title>
<meta name="viewport" content="width=device-width, initial-scale=1" /><meta name="color-scheme" content="dark" /><link rel="icon" href="${FAVICON}" />${css}${head}</head>
<body>
${SPRITE}
<a class="skip" href="#main">Skip to content</a>
${topbar(ctx)}
<main id="main" tabindex="-1">${body}</main>
${scripts}
</body></html>`;
  }

  return { page, topbar, serveAsset };
}

module.exports = { createUi, esc, ext, YT_ICON, TABS, rocket };
