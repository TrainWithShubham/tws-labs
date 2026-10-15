const fs = require('fs');
const pty = require('node-pty');
const WebSocket = require('ws');
const { killProcessSession, killProcessesOfUid } = require('./lib');
const { guardOk } = require('./guards');
const { labEnv } = require('./lab-env');

const MAX_WS_MESSAGE_BYTES = 64 * 1024;

// The terminal: one WebSocket per session token, each driving a real shell in a pty as that session's own user.
function attachTerminal(server, d) {
  const { cfg, store, sandbox, findLab, homeOf, historyOf, idOf, bootstrap } = d;
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
    const lab = findLab(session.meta.track, session.meta.lab);
    if (!lab) { store.expire(token); return ws.close(4004, 'lab not found'); }

    const { uid } = session;
    const home = homeOf(token);
    let shell;
    try {
      sandbox.prepareHome(home, uid);
      const extraEnv = labEnv(lab, cfg);
      const setup = sandbox.runSetup(lab.dir, home, uid, extraEnv);
      if (setup.code !== 0) throw new Error('setup.sh failed:\n' + setup.out);
      sandbox.prepareHistory(historyOf(token), uid);
      // bash, not sh: on Debian sh is dash, which has no `ulimit -u` (and would fail silently).
      const [file, args] = sandbox.asUser(uid, home, 'bash', ['-c', bootstrap]);
      // The environment is deliberately minimal: the learner gets a shell, not this
      // process's config or secrets.
      shell = pty.spawn(file, args, {
        name: 'xterm-256color', cols: 80, rows: 24, cwd: home,
        env: { PATH: process.env.PATH, HOME: home, TERM: 'xterm-256color', LANG: 'C.UTF-8', GIT_TERMINAL_PROMPT: '0', ...extraEnv },
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
    shells.set(token, shell);

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
      shells.delete(token);
      killProcessSession('/proc', shell.pid);
      if (uid !== undefined) killProcessesOfUid('/proc', uid);    // also daemons that escaped via setsid
      try { shell.kill(); } catch { /* already exited */ }
      store.expire(token);
      sandbox.removeTree(home);
      sandbox.removeTree(historyOf(token));
    });
  });
  return { wss, type: (token, text) => { const sh = shells.get(token); if (sh) { try { sh.write(text); return true; } catch { /* gone */ } } return false; } };
}

module.exports = { attachTerminal };
