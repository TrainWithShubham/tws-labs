const { json, readJson } = require('../http');
const { guardOk, tokenOk } = require('../guards');
const { clientIp } = require('../lib');
const { codeId } = require('../usage');
const { labEnv } = require('../lab-env');

// Seats: minting a session, its countdown, and grading a task.
module.exports = function sessionRoutes(router, d) {
  const { cfg, store, pool, sandbox, usage, findLab, historyOf } = d;

  router.post('/session', (req, res) => {
    if (!guardOk(req, cfg, { needOrigin: true })) return json(res, 403, { error: 'forbidden' });
    return readJson(req, res, ({ track, lab }) => {
      const found = findLab(String(track), String(lab));
      if (!found) return json(res, 404, { error: 'unknown lab' });
      if (found.requires === 'aws' && !cfg.isLocal) {
        return json(res, 403, { error: 'needs-local', message: 'This lab uses your own AWS account, so it runs on your machine. The hosted site never asks for AWS keys; see the lab page for how to run it locally.' });
      }
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
  
  });

  router.get('/session/remaining', (req, res, { url }) => {
    const s = store.get(url.searchParams.get('token'));
    const remainingSec = s ? Math.max(0, Math.round((s.createdAt + cfg.hardCapMs - Date.now()) / 1000)) : 0;
    return json(res, 200, { remainingSec });
  
  });

  router.post('/lab/check', (req, res) => {
    if (!guardOk(req, cfg, { needOrigin: true })) return json(res, 403, { pass: false });
    return readJson(req, res, async ({ token, stepId }) => {
      const session = store.get(token);
      if (!session) return json(res, 403, { pass: false });
      const lab = findLab(session.meta.track, session.meta.lab);
      const step = lab && lab.steps.find((s) => s.id === stepId && s.type === 'task');
      if (!step) return json(res, 404, { pass: false });
      if (!session.shellPid) return json(res, 200, { pass: false, message: 'Terminal is still connecting.' });
      const r = await sandbox.runCheck(step.checkFile, {
        home: session.home, uid: session.uid, shellPid: session.shellPid, historyFile: historyOf(token), env: labEnv(lab, cfg),
      });
      usage.check({ track: session.meta.track, lab: session.meta.lab, step: stepId, pass: r.pass, ip: session.ip, code: session.meta.code });
      json(res, 200, { pass: r.pass, message: r.pass ? '' : r.message });
    });
  
  });
};
