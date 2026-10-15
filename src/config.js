// One server, two profiles. `hosted` is the default so the live Elastic Beanstalk
// environment (which sets no app env vars) keeps working unchanged; the local
// docker-compose file sets LAB_PROFILE=local.
//   local  - a learner's own machine: loopback-only, relaxed limits, offline fonts
//   hosted - the public deployment: per-IP seat limits, tight timeouts, same-origin guard
function intEnv(env, names, fallback) {
  for (const name of [].concat(names)) {
    const n = parseInt(env[name], 10);
    if (Number.isFinite(n) && n > 0) return n;
  }
  return fallback;
}

function loadConfig(env = process.env) {
  // LAB_MODE / EB_MODE are the old names; only the value 'local' ever mattered.
  const raw = env.LAB_PROFILE || env.LAB_MODE || env.EB_MODE || 'hosted';
  const profile = raw === 'local' ? 'local' : 'hosted';
  const isLocal = profile === 'local';
  const uidBase = env.LAB_UID ? parseInt(env.LAB_UID, 10) : undefined;
  return {
    profile,
    isLocal,
    port: env.PORT || 8080,
    labsDir: env.LABS_DIR || require('path').join(__dirname, '..', 'labs'),
    sandboxDir: env.SANDBOX_DIR || require('path').join(require('os').tmpdir(), 'tws-labs-sandbox'),
    watch: env.LABS_WATCH === '1',
    // Seats are per replica. Autoscaling is CPU-driven and idle shells use almost
    // no CPU, so extra visitors do not add replicas on their own: total seats =
    // replicas x maxSessions (raise min-replica before an announcement).
    maxSessions: intEnv(env, ['MAX_SESSIONS', 'MAX_CONCURRENT_SESSIONS'], isLocal ? 3 : 5),
    // Per client IP, counting minted-but-unconnected tokens. Kept above 1 because a
    // classroom/campus NAT puts many real learners behind one address. 0 = unlimited.
    maxPerIp: isLocal ? 0 : intEnv(env, 'MAX_SESSIONS_PER_IP', 3),
    idleMs: intEnv(env, 'LAB_IDLE_MIN', isLocal ? 30 : 5) * 60 * 1000,
    hardCapMs: intEnv(env, 'LAB_HARD_CAP_MIN', isLocal ? 120 : 15) * 60 * 1000,
    // The page connects its terminal right after minting; a token that never does
    // must not hold a seat for long.
    connectDeadlineMs: 15 * 1000,
    // -v caps each process's address space so `tail /dev/zero` cannot OOM the pod.
    // LAB_ULIMIT_V_KB=0 disables it (needed when the image runs under x86 emulation, which maps huge address ranges).
    ulimitVKb: env.LAB_ULIMIT_V_KB !== undefined ? parseInt(env.LAB_ULIMIT_V_KB, 10) || 0 : (isLocal ? 1048576 : 262144),
    // Every learner shell gets its own unprivileged uid (uidBase + slot) so one
    // learner cannot read, signal or starve another. Undefined = not root / no drop.
    uidBase,
    trustProxy: !isLocal,          // behind the ALB the rightmost X-Forwarded-For is the client
    chip: isLocal ? 'local' : 'cluster',
    remoteFonts: !isLocal,         // the local app renders fully offline
    // Invite tokens: on the hosted profile every lab needs one (the local app never asks).
    // Comma-separated so a cohort's token can be revoked without touching the others.
    accessTokens: isLocal ? [] : String(env.LAB_ACCESS_TOKENS || env.LAB_ACCESS_TOKEN || '').split(',').map((s) => s.trim()).filter(Boolean),
    // Usage counters (sessions per lab, distinct visitors per day, task pass/fail) are opt-in. They keep no IP address
    // and no invite code. USAGE_DIR keeps them across restarts; the admin page needs its own token and is absent without one.
    usageStats: env.USAGE_STATS === '1',
    usageDir: env.USAGE_DIR || undefined,
    usageSalt: env.USAGE_SALT || undefined,
    usageRetentionDays: intEnv(env, 'USAGE_RETENTION_DAYS', 90),
    adminToken: String(env.ADMIN_TOKEN || '').trim(),
    ownerNote: isLocal ? 'this container' : 'this replica only',
  };
}

module.exports = { loadConfig };
