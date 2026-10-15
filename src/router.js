// A tiny router: routes are tried in the order they were added, the first match wins, and handle() says whether
// anything answered. Order matters (assets before pages, the 404 last), so use() slots a plain function into the same list.
function createRouter() {
  const entries = [];
  const route = (method) => (pattern, handler) => entries.push({ method, pattern, handler });
  return {
    get: route('GET'),
    post: route('POST'),
    use: (fn) => entries.push({ fn }),
    handle(req, res, url) {
      const p = url.pathname;
      for (const e of entries) {
        if (e.fn) { if (e.fn(req, res, p)) return true; continue; }
        if (e.method !== req.method) continue;
        let m = null;
        if (typeof e.pattern === 'string') { if (p !== e.pattern) continue; } else { m = p.match(e.pattern); if (!m) continue; }
        e.handler(req, res, { url, p, m });
        return true;
      }
      return false;
    },
  };
}

module.exports = { createRouter };
