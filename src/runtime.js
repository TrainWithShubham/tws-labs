// Pluggable execution runtime interface for TWS Labs.
// Provides a unified contract for session preparation, terminal spawning,
// check grading, and lifecycle cleanup across execution backends (local process,
// isolated container, or Kubernetes pod).
const pty = require('node-pty');
const { killProcessSession, killProcessesOfUid } = require('./lib');

/**
 * ExecutionRuntime interface contract:
 * {
 *   name: string,
 *   isIsolated: boolean, // true ONLY if an independently enforced container/pod/VM boundary exists per session
 *   provider: string,
 *   prepareHome(home, uid): void,
 *   prepareHistory(historyFile, uid): void,
 *   removeTree(path): void,
 *   runSetup(dir, home, uid, extraEnv, opts): { code: number, out: string },
 *   runChallengeSetup(dir, home, uid, extraEnv, opts): { code: number, out: string },
 *   runScript(scriptPath, { home, uid, env }): Promise<{ code: number, out: string }>,
 *   runCheck(checkFile, { home, uid, shellPid, historyFile }): Promise<{ pass: boolean, message: string }>,
 *   spawnTerminal({ uid, home, historyFile, extraEnv, bootstrap, cols, rows }): ptyProcess,
 *   cleanupSession({ shell, pid, uid, home, historyFile }): void,
 * }
 */

function createLocalProcessRuntime({ cfg, sandbox, bootstrap }) {
  return {
    name: 'local-process',
    // Execution security invariant: single-host Linux DAC / UID dropping is NOT
    // per-session namespace/container isolation. Do not claim isolation.
    isIsolated: false,
    provider: 'local-process-sandbox',

    verifyIsolation() {
      // Single-host DAC UID separation does not provide per-session container/namespace isolation.
      return false;
    },

    prepareHome(home, uid) {
      return sandbox.prepareHome(home, uid);
    },

    prepareHistory(historyFile, uid) {
      return sandbox.prepareHistory(historyFile, uid);
    },

    removeTree(p) {
      return sandbox.removeTree(p);
    },

    runSetup(dir, home, uid, extraEnv = {}, opts = {}) {
      return sandbox.runSetup(dir, home, uid, extraEnv, opts);
    },

    runChallengeSetup(dir, home, uid, extraEnv = {}, opts = {}) {
      if (typeof sandbox.runChallengeSetup === 'function') {
        return sandbox.runChallengeSetup(dir, home, uid, extraEnv, opts);
      }
      return sandbox.runSetup(dir, home, uid, extraEnv, opts);
    },

    runScript(scriptPath, opts) {
      return sandbox.runScript(scriptPath, opts);
    },

    runCheck(checkFile, opts) {
      return sandbox.runCheck(checkFile, opts);
    },

    spawnTerminal({ uid, home, historyFile, extraEnv = {}, bootstrapCmd, cols = 80, rows = 24 }) {
      const cmd = bootstrapCmd || bootstrap;
      const [file, args] = sandbox.asUser(uid, home, 'bash', ['-c', cmd]);
      return pty.spawn(file, args, {
        name: 'xterm-256color',
        cols: Math.max(10, Math.min(300, cols)),
        rows: Math.max(5, Math.min(100, rows)),
        cwd: home,
        env: {
          PATH: process.env.PATH,
          HOME: home,
          TERM: 'xterm-256color',
          LANG: 'C.UTF-8',
          GIT_TERMINAL_PROMPT: '0',
          LAB_HISTORY: historyFile,
          ...extraEnv,
        },
      });
    },

    cleanupSession({ shell, pid, uid, home, historyFile }) {
      if (pid) {
        killProcessSession('/proc', pid);
      }
      if (uid !== undefined) {
        killProcessesOfUid('/proc', uid);
      }
      if (shell) {
        try { shell.kill(); } catch { /* already exited */ }
      }
      if (home) {
        sandbox.removeTree(home);
      }
      if (historyFile) {
        sandbox.removeTree(historyFile);
      }
    },
  };
}

function createExecutionRuntime(cfg, { sandbox, bootstrap }) {
  const provider = (cfg.executionRuntime || process.env.EXECUTION_RUNTIME || 'local').toLowerCase();

  switch (provider) {
    case 'local':
    case 'process':
      return createLocalProcessRuntime({ cfg, sandbox, bootstrap });

    // Future container / Kubernetes runtime plug points:
    case 'kubernetes':
    case 'k8s':
      throw new Error('Kubernetes execution runtime is not yet enabled. Fail-closed: configure EXECUTION_RUNTIME=local');

    case 'container':
    case 'docker':
      throw new Error('Per-session isolated container runtime is not yet enabled. Fail-closed: configure EXECUTION_RUNTIME=local');

    default:
      throw new Error(`Unknown EXECUTION_RUNTIME "${provider}". Supported runtimes: local`);
  }
}

/**
 * Interface validation check for isolated execution backends.
 *
 * WHAT THIS PROVES:
 * - This function verifies ONLY in-process interface compliance and runtime self-attestation.
 * - It confirms that the runtime object implements the isolated execution contract and
 *   returns true from its verifyIsolation() hook.
 *
 * WHAT THIS DOES NOT PROVE:
 * - A self-reported `isIsolated: true` or mock `verifyIsolation()` function is an interface
 *   check, NOT proof that an actual operating system security boundary exists.
 * - Actual execution isolation requires an independently enforced kernel boundary (e.g.,
 *   Kata microVMs, gVisor sandboxes, or isolated Kubernetes Pod sandboxes with strict seccomp,
 *   network namespace isolation, and dedicated cgroups).
 * - Under no circumstances should UID separation or in-memory flags be treated as container isolation.
 */
function hasVerifiedIsolation(runtime) {
  if (!runtime || typeof runtime !== 'object') return false;
  if (runtime.isIsolated !== true) return false;
  if (typeof runtime.verifyIsolation === 'function') {
    return runtime.verifyIsolation() === true;
  }
  return false;
}

module.exports = {
  createExecutionRuntime,
  createLocalProcessRuntime,
  hasVerifiedIsolation,
};
