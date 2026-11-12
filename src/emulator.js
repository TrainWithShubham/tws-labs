// The AWS Emulator sidecar (docker-compose.emulator.yml), for labs that say `requires: emulator`.
// It runs beside the lab container on the same network, so it answers on this container's own loopback, with request signing off
// (nothing outside this container can reach it). Learners get dummy keys, its endpoint and its certificate, and nothing else.
const fs = require('fs');
const https = require('https');

const REGION = 'us-east-1';

const configured = (cfg) => !!(cfg && cfg.emulator && cfg.emulator.endpoint);

// What a learner's shell and checks inherit for an emulator lab. Fixed dummy keys: the emulator ignores them, but the CLI refuses to run without some.
function emulatorEnv(cfg) {
  if (!configured(cfg)) return {};
  return {
    AWS_ENDPOINT_URL: cfg.emulator.endpoint,
    AWS_ACCESS_KEY_ID: 'emulator',
    AWS_SECRET_ACCESS_KEY: 'emulator',
    AWS_REGION: REGION,
    AWS_DEFAULT_REGION: REGION,
    AWS_CA_BUNDLE: cfg.emulator.caFile,
    AWS_EC2_METADATA_DISABLED: 'true',
    AWS_DISABLE_HOST_PREFIX_INJECTION: 'true',
    AWS_PAGER: '',
  };
}

// The emulator writes its certificate where only it (and this server) can read it. Learners' CLIs need to trust it, so a copy goes
// where they can read: it is a public certificate, never a key. Written beside the target and renamed, so a half-written file is never seen.
function ensureCa(cfg) {
  if (!configured(cfg) || !cfg.emulator.caSource) return false;
  try {
    const pem = fs.readFileSync(cfg.emulator.caSource);
    try { if (fs.readFileSync(cfg.emulator.caFile).equals(pem)) return true; } catch { /* not there yet */ }
    const tmp = `${cfg.emulator.caFile}.${process.pid}.tmp`;
    fs.writeFileSync(tmp, pem, { mode: 0o644 });
    fs.chmodSync(tmp, 0o644);
    fs.renameSync(tmp, cfg.emulator.caFile);
    return true;
  } catch {
    return false;
  }
}

// Is the emulator answering? Verified against its own certificate, read from the source file (not the learner-readable copy).
function checkHealth(cfg, { timeoutMs = 2000 } = {}) {
  return new Promise((resolve) => {
    if (!configured(cfg) || !cfg.emulator.caSource) return resolve(false);
    let ca;
    try { ca = fs.readFileSync(cfg.emulator.caSource); } catch { return resolve(false); }   // not written yet: still starting
    let url;
    try { url = new URL('/__admin/health', cfg.emulator.endpoint); } catch { return resolve(false); }
    const req = https.get(url, { ca, timeout: timeoutMs }, (res) => { res.resume(); resolve(res.statusCode === 200); });
    req.on('timeout', () => { req.destroy(); resolve(false); });
    req.on('error', () => resolve(false));
  });
}

module.exports = { emulatorEnv, ensureCa, checkHealth, configured, REGION };
