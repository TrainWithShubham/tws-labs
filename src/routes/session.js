const { json, readJson } = require('../http');
const { guardOk, tokenOk } = require('../guards');
const { clientIp } = require('../lib');
const { codeId } = require('../usage');
const { labEnv } = require('../lab-env');
const { hasVerifiedIsolation } = require('../runtime');

// Seats: minting a session, its countdown, and grading a task.
module.exports = function sessionRoutes(router, d) {
  const { cfg, store, pool, runtime, usage, findLab, historyOf, challengeLoader } = d;
  if (!runtime) {
    throw new Error('sessionRoutes requires an ExecutionRuntime instance');
  }

  router.post('/session', (req, res) => {
    if (!guardOk(req, cfg, { needOrigin: true })) return json(res, 403, { error: 'forbidden' });
    return readJson(req, res, (body) => {
      const isChallenge = body.type === 'challenge' || (body.domain && body.challenge && !body.track && !body.lab);

      let found = null;
      let sessionMeta = null;
      let usageTrack = '';
      let usageLab = '';

      if (isChallenge) {
        if (!challengeLoader) return json(res, 500, { error: 'challenge loader unavailable' });
        const targetDomain = String(body.domain || '');
        const targetSlug = String(body.challenge || '');
        found = challengeLoader.getChallengeInternal(targetDomain, targetSlug);
        if (!found) return json(res, 404, { error: 'unknown challenge' });

        // Hosted execution security policy:
        // Authentication and execution isolation remain strictly independent.
        // A valid invite token does NOT grant trust to execute on a shared process runtime.
        // 1. Authentication check: If challenges are not public, require an invite token.
        const isAuthenticated = tokenOk(req, cfg);
        if (!cfg.isLocal && !cfg.publicChallenges && !isAuthenticated) {
          return json(res, 401, { error: 'token-required', message: 'This challenge needs an invite code.' });
        }

        // 2. Execution isolation check:
        // Hosted shell execution using local-process runtime must fail closed for ALL learners,
        // including authenticated callers, unless a genuinely isolated execution backend is verified.
        if (!cfg.isLocal && !hasVerifiedIsolation(runtime)) {
          return json(res, 403, {
            error: 'untrusted-execution-disabled',
            message: 'Hosted shell execution is disabled without a verified isolated container/VM execution backend.',
          });
        }

        sessionMeta = { type: 'challenge', domain: targetDomain, challenge: targetSlug };
        usageTrack = 'challenge:' + targetDomain;
        usageLab = targetSlug;
      } else {
        const { track, lab } = body;
        found = findLab(String(track), String(lab));
        if (!found) return json(res, 404, { error: 'unknown lab' });
        if (found.requires === 'aws' && !cfg.isLocal) {
          return json(res, 403, { error: 'needs-local', message: 'This lab uses your own AWS account, so it runs on your machine. The hosted site never asks for AWS keys; see the lab page for how to run it locally.' });
        }
        if (!cfg.isLocal && !tokenOk(req, cfg)) {
          return json(res, 401, { error: 'token-required', message: 'This lab needs an invite code.' });
        }
        sessionMeta = { type: 'lab', track: String(track), lab: String(lab) };
        usageTrack = String(track);
        usageLab = String(lab);
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
      const token = store.mint({ ...sessionMeta, code }, ip, uid);
      usage.session({ track: usageTrack, lab: usageLab, ip, code });
      json(res, 200, { token });
    });
  });

  router.get('/session/remaining', (req, res, { url }) => {
    const s = store.get(url.searchParams.get('token'));
    const remainingSec = s ? Math.max(0, Math.round((s.createdAt + cfg.hardCapMs - Date.now()) / 1000)) : 0;
    return json(res, 200, { remainingSec });
  });

  // Skipped ahead? Run the task's setup/<task>.sh in the learner's own sandbox so the files it needs exist, and (if it names a folder)
  // move their shell there. Nothing from the script reaches the browser, and it is safe to run again.
  router.post('/lab/setup', (req, res) => {
    if (!guardOk(req, cfg, { needOrigin: true })) return json(res, 403, { ok: false });
    return readJson(req, res, async ({ token, stepId }) => {
      const session = store.get(token);
      if (!session) return json(res, 403, { ok: false });

      let step = null;
      let extraEnv = {};

      if (session.meta && session.meta.type === 'challenge') {
        const challenge = challengeLoader && challengeLoader.getChallengeInternal(session.meta.domain, session.meta.challenge);
        step = challenge && challenge.steps.find((s) => s.id === stepId && s.type === 'task' && s.setupFile);
      } else {
        const lab = findLab(session.meta.track, session.meta.lab);
        step = lab && lab.steps.find((s) => s.id === stepId && s.type === 'task' && s.setupFile);
        extraEnv = labEnv(lab, cfg);
      }

      if (!step) return json(res, 404, { ok: false });
      if (!session.shellPid) return json(res, 200, { ok: false, message: 'Terminal is still connecting.' });
      const out = await runtime.runScript(step.setupFile, { home: session.home, uid: session.uid, env: extraEnv });
      if (out.code !== 0) return json(res, 200, { ok: false, message: 'Could not prepare the files for this task.' });
      if (step.setupCwd && d.terminal) d.terminal.type(token, `\u0015cd '${step.setupCwd}'\r`);   // Ctrl-U clears a half-typed line first
      json(res, 200, { ok: true });
    });
  });

  router.post('/lab/check', (req, res) => {
    if (!guardOk(req, cfg, { needOrigin: true })) return json(res, 403, { pass: false });
    return readJson(req, res, async ({ token, stepId }) => {
      const session = store.get(token);
      if (!session) return json(res, 403, { pass: false });

      let step = null;
      let extraEnv = {};
      let trackName = '';
      let labName = '';
      let timeoutMs = undefined;

      if (session.meta && session.meta.type === 'challenge') {
        const challenge = challengeLoader && challengeLoader.getChallengeInternal(session.meta.domain, session.meta.challenge);
        step = challenge && challenge.steps.find((s) => s.id === stepId && s.type === 'task');
        trackName = 'challenge:' + session.meta.domain;
        labName = session.meta.challenge;
      } else {
        const lab = findLab(session.meta.track, session.meta.lab);
        step = lab && lab.steps.find((s) => s.id === stepId && s.type === 'task');
        trackName = session.meta.track;
        labName = session.meta.lab;
        extraEnv = labEnv(lab, cfg);
        timeoutMs = lab && lab.requires === 'aws' ? 30000 : undefined;
      }

      if (!step) return json(res, 404, { pass: false });
      if (!session.shellPid) return json(res, 200, { pass: false, message: 'Terminal is still connecting.' });
      const r = await runtime.runCheck(step.checkFile, {
        home: session.home, uid: session.uid, shellPid: session.shellPid, historyFile: historyOf(token), env: extraEnv,
        timeoutMs,
      });
      usage.check({ track: trackName, lab: labName, step: stepId, pass: r.pass, ip: session.ip, code: session.meta.code });
      json(res, 200, { pass: r.pass, message: r.pass ? '' : r.message });
    });
  });
};
