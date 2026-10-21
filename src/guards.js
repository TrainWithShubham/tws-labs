const crypto = require('crypto');

// --- Request guards -------------------------------------------------------------
// This app hands out a real shell, so a web page the visitor happens to have open
// must not be able to drive it.
//  local  : Host and Origin must be loopback names and the Origin must be this server's own, port included (stops DNS rebinding and CSRF
//           against localhost:8080, even from another localhost port).
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
  // Both profiles: the Origin must be this server's own. On the local profile it must also be a loopback name, so a page or dev server on
  // another localhost port (a different origin) cannot open a shell here.
  return originHost === String(req.headers.host || '').toLowerCase() && (!cfg.isLocal || LOOPBACK.has(hostnameOf(originHost)));
}

// Hosted only: every lab needs one of the configured invite tokens (the local app never asks). Compared as
// SHA-256 digests so length and content never leak through timing. No tokens
// configured means closed, never open.
const digest = (s) => crypto.createHash('sha256').update(String(s)).digest();
function tokenOk(req, cfg) {
  const given = digest(req.headers['x-lab-token'] || '');
  return cfg.accessTokens.reduce((ok, t) => crypto.timingSafeEqual(given, digest(t)) || ok, false);
}

module.exports = { LOOPBACK, hostnameOf, hostOk, guardOk, digest, tokenOk };
