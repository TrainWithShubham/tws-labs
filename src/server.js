const http = require('http');
const fs = require('fs');
const path = require('path');
const os = require('os');
const {
  createSessionStore, createUidPool,
} = require('./lib');
const { loadConfig } = require('./config');
const { loadCatalog } = require('./loader');
const { loadSite } = require('./site');
const { loadRoadmap } = require('./roadmap');
const { createUi } = require('./ui');
const { createSandbox } = require('./sandbox');
const { createStats } = require('./stats');
const { createUsage } = require('./usage');
const { createRouter } = require('./router');
const { send } = require('./http');
const { hostOk, guardOk, hostnameOf } = require('./guards');
const { attachTerminal } = require('./terminal');
const systemRoutes = require('./routes/system');
const siteRoutes = require('./routes/site');
const sessionRoutes = require('./routes/session');
const pages = require('./pages');

const XTERM_DIR = path.join(__dirname, '..', 'node_modules', '@xterm');
const BASHRC = path.join(__dirname, 'lab.bashrc');

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

  const router = createRouter();
  const deps = {
    cfg, ui, store, pool, sandbox, stats, usage, ctxFor, page, getCatalog, getRoadmap, getSite, findLab,
    idOf, homeOf, historyOf, bootstrap,
  };
  systemRoutes(router, deps);
  router.use((req, res, p) => ui.serveAsset(req, res, p));
  siteRoutes(router, deps);
  sessionRoutes(router, deps);

  const server = http.createServer((req, res) => {
    // Local profile: refuse any non-loopback Host outright (DNS rebinding).
    if (!hostOk(req, cfg)) return send(res, 421, 'text/plain', 'This app only answers on localhost.');
    const url = new URL(req.url, 'http://localhost');
    if (!router.handle(req, res, url)) send(res, 404, 'text/html', page('labs', 'Not found', pages.notFoundBody()));
  });

  attachTerminal(server, deps);

  server.on('close', () => stats.stop());
  return { server, cfg, store, getCatalog };
}

if (require.main === module) {
  const { server, cfg } = createApp();
  server.listen(cfg.port, () => console.log(`TWS Labs listening on ${cfg.port}, profile=${cfg.profile}, seats=${cfg.maxSessions}/replica, labs=${cfg.labsDir}`));
}

module.exports = { createApp, guardOk, hostOk, hostnameOf };
