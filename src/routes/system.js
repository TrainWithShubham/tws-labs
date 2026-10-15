const crypto = require('crypto');
const { send, json } = require('../http');
const { digest } = require('../guards');
const pages = require('../pages');

// Liveness, seat pressure, and the token-protected usage page.
module.exports = function systemRoutes(router, d) {
  const { cfg, stats, store, usage, page } = d;

  router.get('/healthz', (req, res) => send(res, 200, 'text/plain', 'ok'));

  router.get('/stats', (req, res) => {
    // sessions/maxSessions let an operator see seat pressure per replica without shell access.
    json(res, 200, { ...stats.get(), sessions: store.size(), maxSessions: cfg.maxSessions, profile: cfg.profile });
  });

  // Off (404) unless an ADMIN_TOKEN is configured; the token travels in a header, never in the URL.
  router.get('/admin/stats', (req, res) => {
    if (!cfg.adminToken) return send(res, 404, 'text/html', page('labs', 'Not found', pages.notFoundBody()));
    const given = digest((req.headers.authorization || '').replace(/^Bearer /i, ''));
    if (!crypto.timingSafeEqual(given, digest(cfg.adminToken))) return json(res, 401, { error: 'unauthorized' }, { 'WWW-Authenticate': 'Bearer' });
    json(res, 200, usage.summary(), { 'Cache-Control': 'no-store' });
  });
};
