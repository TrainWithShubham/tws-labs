const http = require('http');
const fs = require('fs');
const path = require('path');
const os = require('os');
const crypto = require('crypto');
const pty = require('node-pty');
const WebSocket = require('ws');
const {
  createSessionStore, createUidPool, killProcessSession, killProcessesOfUid, clientIp,
} = require('./lib');
const { loadConfig } = require('./config');
const { loadCatalog } = require('./loader');
const { loadSite } = require('./site');
const { loadRoadmap } = require('./roadmap');
const { createUi } = require('./ui');
const { createSandbox } = require('./sandbox');
const { createStats } = require('./stats');
const { createUsage, codeId } = require('./usage');
const pages = require('./pages');

const XTERM_DIR = path.join(__dirname, '..', 'node_modules', '@xterm');
const BASHRC = path.join(__dirname, 'lab.bashrc');
const MAX_WS_MESSAGE_BYTES = 64 * 1024;
const MAX_JSON_BODY_BYTES = 4 * 1024;

// --- Request guards -------------------------------------------------------------
// This app hands out a real shell, so a web page the visitor happens to have open
// must not be able to drive it.
//  local  : Host and Origin must be loopback names (stops DNS rebinding and CSRF
//           against localhost:8080).
//  hosted : Origin must equal Host (same-origin); Host is whatever the ALB serves.
// State-changing requests (POST, WebSocket) must carry an Origin; browsers always send one.
const LOOPBACK = new Set(['localhost', '127.0.0.1', '[::1]']);
function hostnameOf(hostHeader) {
  const h = String(hostHeader || '').toLowerCase();
  return h.startsWith('[') ? h.slice(0, h.indexOf(']') + 1) : h.split(':')[0];
}
// Local profile only: any Host that is not a loopback name is a DNS-rebinding attempt.
function hostOk(req, cfg) {
  return !cfg.isLocal || LOOPBACK.has(hostnameOf(req.headers.host));
}
function guardOk(req, cfg, { needOrigin }) {
  const origin = req.headers.origin;
  if (!hostOk(req, cfg)) return false;
  if (!origin) return !needOrigin;
  let originHost;
  try { originHost = new URL(origin).host.toLowerCase(); } catch { return false; }
  return cfg.isLocal ? LOOPBACK.has(hostnameOf(originHost)) : originHost === String(req.headers.host || '').toLowerCase();
}

// Hosted only: every lab needs one of the configured invite tokens (the local app never asks). Compared as
// SHA-256 digests so length and content never leak through timing. No tokens
// configured means closed, never open.
const digest = (s) => crypto.createHash('sha256').update(String(s)).digest();
function tokenOk(req, cfg) {
  const given = digest(req.headers['x-lab-token'] || '');
  return cfg.accessTokens.reduce((ok, t) => crypto.timingSafeEqual(given, digest(t)) || ok, false);
}

function send(res, status, type, body, extra = {}) {
  res.writeHead(status, { 'Content-Type': type, ...extra });
  res.end(body);
}
const json = (res, status, obj, extra) => send(res, status, 'application/json', JSON.stringify(obj), extra);

function readJson(req, res, cb) {
  let body = '';
  let tooBig = false;
  req.on('data', (c) => {
    if (tooBig) return;
    body += c;
    // Answer, then close the connection (rather than destroying it mid-response) and stop buffering.
    if (body.length > MAX_JSON_BODY_BYTES) { tooBig = true; json(res, 413, { error: 'too large', pass: false }, { Connection: 'close' }); }
  });
  req.on('end', () => {
    if (tooBig) return;
    let parsed;
    try { parsed = JSON.parse(body); } catch { return json(res, 400, { error: 'bad json' }); }
    cb(parsed || {});
  });
}

// A factory, not a singleton: each call builds a fully independent server (own
// session store, own catalog), so tests can run as many isolated instances as they like.
function createApp(opts = {}) {
  const env = { ...process.env };
  if (opts.profile) env.LAB_PROFILE = opts.profile;
  const { profile, ...rest } = opts;
  const cfg = { ...loadConfig(env), ...rest };

  const ui = createUi({ chip: cfg.chip, chipTitle: `pod ${os.hostname()}`, remoteFonts: cfg.remoteFonts, xtermDir: XTERM_DIR });
  const sandbox = createSandbox({ labsDir: cfg.labsDir });
  const stats = createStats();
  const usage = createUsage({
    enabled: cfg.usageStats, secret: cfg.usageSalt, dir: cfg.usageDir, retentionDays: cfg.usageRetentionDays,
    log: (line) => console.log('usage ' + line),   // stdout, so the platform's log service keeps it
  });
  const pool = createUidPool(cfg.uidBase, cfg.maxSessions);

  fs.mkdirSync(cfg.sandboxDir, { recursive: true });
  try { fs.chmodSync(cfg.sandboxDir, 0o711); } catch { /* not ours to chmod */ }   // traversable, not listable

  const store = createSessionStore({ connectDeadlineMs: cfg.connectDeadlineMs, onExpire: (s) => pool.release(s.uid) });

  let catalog = loadCatalog(cfg.labsDir);
  const siteFile = path.join(cfg.labsDir, 'site.yaml');
  const roadmapFile = path.join(cfg.labsDir, 'roadmap.json');   // content lives with the labs, wherever LABS_DIR points
  let site = loadSite(siteFile);
  [...catalog.problems, ...site.problems].forEach((p) => console.warn('content problem: ' + p));
  const getCatalog = () => (cfg.watch ? (catalog = loadCatalog(cfg.labsDir)) : catalog);
  const getSite = () => (cfg.watch ? (site = loadSite(siteFile)) : site);
  let roadmap = loadRoadmap(catalog, roadmapFile);
  roadmap.problems.forEach((p) => console.warn('roadmap problem: ' + p));
  const getRoadmap = () => (cfg.watch ? (roadmap = loadRoadmap(getCatalog(), roadmapFile)) : roadmap);
  const ctxFor = (active) => ({ active, site: getSite() });
  const findLab = (t, l) => getCatalog().tracks.find((x) => x.id === t)?.labs.find((x) => x.id === l);
  const page = (active, title, body, scripts) => ui.page(ctxFor(active), title, body, scripts);

  const idOf = (token) => token.slice(0, 8);
  const homeOf = (token) => path.join(cfg.sandboxDir, idOf(token));
  const historyOf = (token) => path.join(cfg.sandboxDir, `.${idOf(token)}.history`);

  // Per-shell guards (fork bombs, runaway memory, huge files) applied before the learner gets the shell.
  // ulimit -v bounds one process, not the sum over concurrent sessions, so under real memory pressure the
  // kernel must pick a learner's process, never the server that serves everyone. A process may always RAISE
  // its own oom_score_adj (no capability needed), and children inherit it.
  const bootstrap = `echo 1000 > /proc/self/oom_score_adj 2>/dev/null; ulimit -u 256 2>/dev/null; ${cfg.ulimitVKb > 0 ? `ulimit -v ${cfg.ulimitVKb} 2>/dev/null; ` : ''}ulimit -f 40960 2>/dev/null; exec bash --rcfile ${BASHRC} -i`;

  const server = http.createServer((req, res) => {
    // Local profile: refuse any non-loopback Host outright (DNS rebinding).
    if (!hostOk(req, cfg)) return send(res, 421, 'text/plain', 'This app only answers on localhost.');
    const url = new URL(req.url, 'http://localhost');
    const p = url.pathname;
    let m;

    if (req.method === 'GET' && p === '/healthz') return send(res, 200, 'text/plain', 'ok');
    if (req.method === 'GET' && p === '/stats') {
      // sessions/maxSessions let an operator see seat pressure per replica without shell access.
      return json(res, 200, { ...stats.get(), sessions: store.size(), maxSessions: cfg.maxSessions, profile: cfg.profile });
    }
    // Off (404) unless an ADMIN_TOKEN is configured; the token travels in a header, never in the URL.
    if (req.method === 'GET' && p === '/admin/stats') {
      if (!cfg.adminToken) return send(res, 404, 'text/html', page('labs', 'Not found', pages.notFoundBody()));
      const given = digest((req.headers.authorization || '').replace(/^Bearer /i, ''));
      if (!crypto.timingSafeEqual(given, digest(cfg.adminToken))) return json(res, 401, { error: 'unauthorized' }, { 'WWW-Authenticate': 'Bearer' });
      return json(res, 200, usage.summary(), { 'Cache-Control': 'no-store' });
    }
    if (ui.serveAsset(req, res, p)) return;

    if (req.method === 'GET' && p === '/') {
      const home = pages.homeBody(getCatalog(), getRoadmap(), cfg);
      return send(res, 200, 'text/html', ui.page(ctxFor('labs'), 'Home', home.body, home.scripts, home.head));
    }
    if (req.method === 'GET' && p === '/videos') {
      return send(res, 200, 'text/html', ui.page(ctxFor('videos'), 'Videos', pages.videosBody(getRoadmap(), getSite()), '', '<script>document.documentElement.classList.add("js")</script><link rel="stylesheet" href="/roadmap.css" />'));
    }
    if (req.method === 'GET' && p === '/upcoming') { res.writeHead(301, { Location: '/roadmap' }); return res.end(); }
    if (req.method === 'GET' && p === '/roadmap') {
      return send(res, 200, 'text/html', ui.page(ctxFor('roadmap'), 'Roadmap', pages.roadmapBody(getRoadmap()),
        '<script src="/roadmap.js"></script><script src="/progress.js"></script>', '<script>document.documentElement.classList.add("js")</script><link rel="stylesheet" href="/roadmap.css" />'));
    }
    if (req.method === 'GET' && (m = p.match(/^\/t\/([a-z0-9-]+)$/))) {
      const track = getCatalog().tracks.find((t) => t.id === m[1]);
      if (!track) return send(res, 404, 'text/html', page('labs', 'Not found', pages.notFoundBody()));
      return send(res, 200, 'text/html', page('labs', track.title, pages.trackBody(track, pages.placeOf(getRoadmap(), track.id)), '<script src="/progress.js"></script>'));
    }
    // The page shell takes no seat; the page's JS mints a session with POST /session.
    if (req.method === 'GET' && (m = p.match(/^\/lab\/([a-z0-9-]+)\/([a-z0-9-]+)$/))) {
      const lab = findLab(m[1], m[2]);
      if (!lab) return send(res, 404, 'text/html', page('labs', 'Not found', pages.notFoundBody()));
      const trackTitle = getCatalog().tracks.find((x) => x.id === lab.track).title;
      const { body, scripts } = pages.labBody(lab, trackTitle, cfg, pages.placeOf(getRoadmap(), lab.track), pages.nextLab(getCatalog(), lab.track, lab.id));
      return send(res, 200, 'text/html', page('labs', lab.title, body, scripts), { 'Cache-Control': 'no-store' });
    }

    if (req.method === 'POST' && p === '/session') {
      if (!guardOk(req, cfg, { needOrigin: true })) return json(res, 403, { error: 'forbidden' });
      return readJson(req, res, ({ track, lab }) => {
        const found = findLab(String(track), String(lab));
        if (!found) return json(res, 404, { error: 'unknown lab' });
        if (!cfg.isLocal && !tokenOk(req, cfg)) {
          return json(res, 401, { error: 'token-required', message: 'This lab needs an invite code.' });
        }
        const ip = clientIp(req, { trustProxy: cfg.trustProxy });
        // Retry-After + client auto-retry: a visitor who hits a full replica just waits
        // (the ALB may land the retry on a less-busy one) instead of a dead end.
        if (store.size() >= cfg.maxSessions) {
          return json(res, 503, { error: 'busy', message: 'All lab seats on this server are taken right now. A seat usually frees up within a few minutes.' }, { 'Retry-After': '15' });
        }
        if (cfg.maxPerIp && store.countByIp(ip) >= cfg.maxPerIp) {
          return json(res, 429, { error: 'too-many', message: 'You already have labs open. Close your other lab tabs (or press End lab) and try again.' }, { 'Retry-After': '30' });
        }
        const uid = pool.acquire();
        if (uid === null) return json(res, 503, { error: 'busy', message: 'No free sandbox slot right now.' }, { 'Retry-After': '15' });
        const invite = req.headers['x-lab-token'];
        const code = invite && !cfg.isLocal ? codeId(invite) : undefined;   // only its short hash is ever kept
        const token = store.mint({ track: String(track), lab: String(lab), code }, ip, uid);
        usage.session({ track: String(track), lab: String(lab), ip, code });
        json(res, 200, { token });
      });
    }

    if (req.method === 'GET' && p === '/session/remaining') {
      const s = store.get(url.searchParams.get('token'));
      const remainingSec = s ? Math.max(0, Math.round((s.createdAt + cfg.hardCapMs - Date.now()) / 1000)) : 0;
      return json(res, 200, { remainingSec });
    }

    if (req.method === 'POST' && p === '/lab/check') {
      if (!guardOk(req, cfg, { needOrigin: true })) return json(res, 403, { pass: false });
      return readJson(req, res, async ({ token, stepId }) => {
        const session = store.get(token);
        if (!session) return json(res, 403, { pass: false });
        const lab = findLab(session.meta.track, session.meta.lab);
        const step = lab && lab.steps.find((s) => s.id === stepId && s.type === 'task');
        if (!step) return json(res, 404, { pass: false });
        if (!session.shellPid) return json(res, 200, { pass: false, message: 'Terminal is still connecting.' });
        const r = await sandbox.runCheck(step.checkFile, {
          home: session.home, uid: session.uid, shellPid: session.shellPid, historyFile: historyOf(token),
        });
        usage.check({ track: session.meta.track, lab: session.meta.lab, step: stepId, pass: r.pass, ip: session.ip, code: session.meta.code });
        json(res, 200, { pass: r.pass, message: r.pass ? '' : r.message });
      });
    }

    send(res, 404, 'text/html', page('labs', 'Not found', pages.notFoundBody()));
  });

  const wss = new WebSocket.Server({
    server, path: '/ws', maxPayload: MAX_WS_MESSAGE_BYTES,
    verifyClient: ({ req }) => guardOk(req, cfg, { needOrigin: true }),
  });

  wss.on('connection', (ws, req) => {
    const token = new URL(req.url, 'http://localhost').searchParams.get('token');
    const session = store.get(token);
    if (!session) return ws.close(4001, 'invalid or expired session');
    if (session.shellPid) return ws.close(4002, 'session already connected');   // one terminal per token
    const lab = findLab(session.meta.track, session.meta.lab);
    if (!lab) { store.expire(token); return ws.close(4004, 'lab not found'); }

    const { uid } = session;
    const home = homeOf(token);
    let shell;
    try {
      sandbox.prepareHome(home, uid);
      const setup = sandbox.runSetup(lab.dir, home, uid);
      if (setup.code !== 0) throw new Error('setup.sh failed:\n' + setup.out);
      sandbox.prepareHistory(historyOf(token), uid);
      // bash, not sh: on Debian sh is dash, which has no `ulimit -u` (and would fail silently).
      const [file, args] = sandbox.asUser(uid, home, 'bash', ['-c', bootstrap]);
      // The environment is deliberately minimal: the learner gets a shell, not this
      // process's config or secrets.
      shell = pty.spawn(file, args, {
        name: 'xterm-256color', cols: 80, rows: 24, cwd: home,
        env: { PATH: process.env.PATH, HOME: home, TERM: 'xterm-256color', LANG: 'C.UTF-8', GIT_TERMINAL_PROMPT: '0' },
      });
    } catch (e) {
      // A resource-exhausted host must not crash the process for every other visitor.
      console.error(`session ${idOf(token)} could not start:`, e.message);
      sandbox.removeTree(home);
      sandbox.removeTree(historyOf(token));
      store.expire(token);
      return ws.close(1011, 'could not start the lab sandbox');
    }
    store.markConnected(token, { shellPid: shell.pid, home });

    const hardTimer = setTimeout(() => ws.close(4000, 'session time limit reached'), cfg.hardCapMs);
    let idleTimer = setTimeout(() => ws.close(4000, 'idle timeout'), cfg.idleMs);
    const resetIdle = () => {
      store.touch(token);
      clearTimeout(idleTimer);
      idleTimer = setTimeout(() => ws.close(4000, 'idle timeout'), cfg.idleMs);
    };

    shell.onData((d) => { if (ws.readyState === WebSocket.OPEN) ws.send(d); });
    // `exit` / Ctrl-D ends the shell; without this the browser sits on a dead terminal holding a seat.
    shell.onExit(() => { if (ws.readyState === WebSocket.OPEN) ws.close(1000, 'shell exited'); });
    // Without a listener an 'error' event (malformed/oversized frame) is an uncaught exception for everyone.
    ws.on('error', () => ws.terminate());

    ws.on('message', (data) => {
      resetIdle();
      const text = data.toString();
      if (text.startsWith('\u0000resize:')) {                  // out-of-band control frame (NUL-prefixed)
        const mm = text.slice(8).match(/^(\d{1,3}),(\d{1,3})$/);
        if (mm) { try { shell.resize(Math.min(300, Math.max(10, +mm[1])), Math.min(100, Math.max(5, +mm[2]))); } catch { /* gone */ } }
        return;
      }
      const lines = store.recordInput(token, text);
      if (lines.length) { try { fs.appendFileSync(historyOf(token), lines.join('\n') + '\n'); } catch { /* best effort */ } }
      shell.write(text);
    });

    ws.on('close', () => {
      clearTimeout(hardTimer);
      clearTimeout(idleTimer);
      killProcessSession('/proc', shell.pid);
      if (uid !== undefined) killProcessesOfUid('/proc', uid);    // also daemons that escaped via setsid
      try { shell.kill(); } catch { /* already exited */ }
      store.expire(token);
      sandbox.removeTree(home);
      sandbox.removeTree(historyOf(token));
    });
  });

  server.on('close', () => stats.stop());
  return { server, cfg, store, getCatalog };
}

if (require.main === module) {
  const { server, cfg } = createApp();
  server.listen(cfg.port, () => console.log(`TWS Labs listening on ${cfg.port}, profile=${cfg.profile}, seats=${cfg.maxSessions}/replica, labs=${cfg.labsDir}`));
}

module.exports = { createApp, guardOk, hostOk, hostnameOf };
