// Privacy-light usage counters: how many sessions per lab, how many distinct visitors, which tasks people fail.
// Off unless enabled. Never stores an IP address or an invite code: a visitor is a short keyed hash that
// changes every UTC day, and an invite code is the first 8 hex of its SHA-256 (the code itself is long and random).
// Events are one JSON line each: handed to `log` (stdout, so a platform log service keeps them) and, when a
// directory is given, appended to <dir>/usage.jsonl and replayed on start (older than the retention are dropped).
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const DAY_MS = 24 * 3600 * 1000;
const dayOf = (t) => new Date(t).toISOString().slice(0, 10);
const codeId = (token) => crypto.createHash('sha256').update(String(token)).digest('hex').slice(0, 8);

function createUsage({ enabled = false, secret, dir, retentionDays = 90, now = Date.now, log = () => {} } = {}) {
  if (!enabled) return { session() {}, check() {}, summary: () => ({ enabled: false }) };

  const key = secret || crypto.randomBytes(32).toString('hex');   // no secret: ids differ after a restart, which only costs accuracy
  const visitorId = (ip, day) => crypto.createHmac('sha256', key).update(`${day}|${ip}`).digest('hex').slice(0, 12);
  const days = {};
  const visitorSets = {};
  const since = now();

  const bucket = (day, labKey) => {
    const d = days[day] || (days[day] = { sessions: 0, visitors: 0, labs: {}, codes: {} });
    visitorSets[day] = visitorSets[day] || new Set();
    const lab = labKey ? (d.labs[labKey] || (d.labs[labKey] = { sessions: 0, checks: { pass: 0, fail: 0 }, tasks: {} })) : null;
    return { d, lab, set: visitorSets[day] };
  };

  function apply(e) {
    if ((e.ev !== 'session' && e.ev !== 'check') || !Number.isFinite(e.t) || !e.track || !e.lab) return;
    const day = dayOf(e.t);
    const { d, lab, set } = bucket(day, `${e.track}/${e.lab}`);
    if (e.v && !set.has(e.v)) { set.add(e.v); d.visitors = set.size; }
    if (e.ev === 'session') {
      d.sessions += 1; lab.sessions += 1;
      if (e.c) d.codes[e.c] = (d.codes[e.c] || 0) + 1;
    } else if (e.step) {
      const k = e.pass ? 'pass' : 'fail';
      lab.checks[k] += 1;
      const task = lab.tasks[e.step] || (lab.tasks[e.step] = { pass: 0, fail: 0 });
      task[k] += 1;
    }
  }

  const file = dir ? path.join(dir, 'usage.jsonl') : null;
  let target = file;
  if (file) {
    try {
      fs.mkdirSync(dir, { recursive: true });
      const cutoff = now() - retentionDays * DAY_MS;
      let kept = [];
      if (fs.existsSync(file)) {
        for (const line of fs.readFileSync(file, 'utf8').split('\n')) {
          let e; try { e = JSON.parse(line); } catch { continue; }
          if (!e || !Number.isFinite(e.t) || e.t < cutoff) continue;
          apply(e); kept.push(line);
        }
      }
      fs.writeFileSync(file, kept.length ? kept.join('\n') + '\n' : '');
    } catch { target = null; }   // unwritable: keep counting in memory and on stdout
  }

  function record(ev, { track, lab, step, pass, ip, token, code }) {
    const t = now();
    const e = { t, ev, track, lab };
    if (step !== undefined) e.step = String(step);
    if (pass !== undefined) e.pass = !!pass;
    if (ip) e.v = visitorId(ip, dayOf(t));
    if (code) e.c = String(code);
    else if (token) e.c = codeId(token);
    apply(e);
    const line = JSON.stringify(e);
    try { log(line); } catch { /* logging must never break a request */ }
    if (target) { try { fs.appendFileSync(target, line + '\n'); } catch { /* best effort */ } }
  }

  // Across every kept day: the tasks learners fail most. Needs a few attempts before a rate means anything.
  const MIN_ATTEMPTS = 5;
  function hardestTasks() {
    const all = new Map();
    for (const d of Object.values(days)) {
      for (const [labKey, lab] of Object.entries(d.labs)) {
        for (const [step, t] of Object.entries(lab.tasks)) {
          const k = `${labKey}\u0000${step}`;
          const acc = all.get(k) || { lab: labKey, step, attempts: 0, passes: 0 };
          acc.attempts += t.pass + t.fail; acc.passes += t.pass;
          all.set(k, acc);
        }
      }
    }
    return [...all.values()]
      .filter((t) => t.attempts >= MIN_ATTEMPTS)
      .map((t) => ({ ...t, passRate: Math.round((t.passes / t.attempts) * 100) / 100 }))
      .sort((a, b) => a.passRate - b.passRate || b.attempts - a.attempts)
      .slice(0, 10);
  }

  return {
    session: (x) => record('session', x),
    check: (x) => record('check', x),
    summary: () => ({ enabled: true, since: new Date(since).toISOString(), retentionDays, days: JSON.parse(JSON.stringify(days)), hardestTasks: hardestTasks() }),
  };
}

module.exports = { createUsage, codeId };
