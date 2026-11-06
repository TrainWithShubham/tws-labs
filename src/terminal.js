const fs = require('fs');
const WebSocket = require('ws');
const { guardOk } = require('./guards');
const { labEnv } = require('./lab-env');

const MAX_WS_MESSAGE_BYTES = 64 * 1024;

// The terminal: one WebSocket per session token, driving a real shell via ExecutionRuntime.
function attachTerminal(server, d) {
  const { cfg, store, runtime, findLab, homeOf, historyOf, idOf, bootstrap } = d;
  if (!runtime) {
    throw new Error('attachTerminal requires an ExecutionRuntime instance');
  }
  const shells = new Map();   // session token -> its pty, so the server can type into it (e.g. to move a skipped-ahead learner into the right folder)
  const wss = new WebSocket.Server({
    server, path: '/ws', maxPayload: MAX_WS_MESSAGE_BYTES,
    verifyClient: ({ req }) => guardOk(req, cfg, { needOrigin: true }),
  });

  wss.on('connection', (ws, req) => {
    const token = new URL(req.url, 'http://localhost').searchParams.get('token');
    const session = store.get(token);
    if (!session) return ws.close(4001, 'invalid or expired session');
    if (session.shellPid) return ws.close(4002, 'session already connected');   // one terminal per token
    let entity = null;
    let extraEnv = {};

    const isChallenge = session.meta && session.meta.type === 'challenge';
    if (isChallenge) {
      entity = d.challengeLoader && d.challengeLoader.getChallengeInternal(session.meta.domain, session.meta.challenge);
      if (!entity) { store.expire(token); return ws.close(4004, 'challenge not found'); }
    } else {
      entity = findLab(session.meta.track, session.meta.lab);
      if (!entity) { store.expire(token); return ws.close(4004, 'lab not found'); }
      extraEnv = labEnv(entity, cfg);
    }

    const { uid } = session;
    const home = homeOf(token);
    let shell;
    try {
      runtime.prepareHome(home, uid);
      const setup = isChallenge
        ? runtime.runChallengeSetup(entity.dir, home, uid, extraEnv, { isolateOutput: entity.slug === 'process-resource' || entity.id === 'LNX-CH-030' || entity.slug === 'process-service-fundamentals' || entity.id === 'LNX-CH-005' })
        : runtime.runSetup(entity.dir, home, uid, extraEnv);
      if (setup.code !== 0) throw new Error('setup.sh failed:\n' + setup.out);
      runtime.prepareHistory(historyOf(token), uid);
      shell = runtime.spawnTerminal({ uid, home, historyFile: historyOf(token), extraEnv, bootstrapCmd: bootstrap });
    } catch (e) {
      // A resource-exhausted host must not crash the process for every other visitor.
      console.error(`session ${idOf(token)} could not start:`, e.message);
      runtime.cleanupSession({ home, historyFile: historyOf(token) });
      store.expire(token);
      return ws.close(1011, 'could not start the lab sandbox');
    }
    store.markConnected(token, { shellPid: shell.pid, home });
    shells.set(token, shell);

    const hardTimer = setTimeout(() => ws.close(4000, 'session time limit reached'), cfg.hardCapMs);
    let idleTimer = setTimeout(() => ws.close(4000, 'idle timeout'), cfg.idleMs);
    const resetIdle = () => {
      store.touch(token);
      clearTimeout(idleTimer);
      idleTimer = setTimeout(() => ws.close(4000, 'idle timeout'), cfg.idleMs);
    };

    pipeWithBackpressure(shell, ws);
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
      shells.delete(token);
      runtime.cleanupSession({ shell, pid: shell.pid, uid, home, historyFile: historyOf(token) });
      store.expire(token);
    });
  });
  return { wss, type: (token, text) => { const sh = shells.get(token); if (sh) { try { sh.write(text); return true; } catch { /* gone */ } } return false; } };
}

// Forward pty output to the browser. A client that reads slowly (a throttled background tab, a stalled network) must not make the server buffer
// whatever `yes` produces: past HIGH bytes still waiting to go out, stop reading the pty (the shell then blocks on its own write, as it would on a
// real terminal) and carry on once the browser has caught up to LOW.
const HIGH = 1024 * 1024;
const LOW = 256 * 1024;
function pipeWithBackpressure(shell, ws, { high = HIGH, low = LOW } = {}) {
  let pending = 0;
  let paused = false;
  shell.onData((data) => {
    if (ws.readyState !== WebSocket.OPEN) return;
    const size = Buffer.byteLength(data);
    pending += size;
    ws.send(data, () => {
      pending -= size;
      if (paused && pending <= low) { paused = false; try { shell.resume(); } catch { /* gone */ } }
    });
    if (!paused && pending > high) { paused = true; try { shell.pause(); } catch { /* gone */ } }
  });
}

module.exports = { attachTerminal, pipeWithBackpressure };
