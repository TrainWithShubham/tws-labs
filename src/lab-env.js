// What a learner's shell and checks may inherit from the server's environment. By default nothing: the learner
// gets a shell, not this process's config or secrets (invite codes, the admin token, the usage salt).
// The one deliberate exception: a lab that says `requires: aws` on the LOCAL profile gets the learner's own AWS
// variables, which they set on their own machine. The hosted profile never passes credentials.
const AWS_ENV = ['AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'AWS_SESSION_TOKEN', 'AWS_REGION', 'AWS_DEFAULT_REGION', 'AWS_PROFILE'];

function labEnv(lab, cfg, source = process.env) {
  if (!lab || lab.requires !== 'aws' || !cfg.isLocal) return {};
  const env = {};
  for (const name of AWS_ENV) if (source[name]) env[name] = source[name];
  return env;
}

// The offline validator (`scripts/validate-labs.js`) cannot run an account lab. It only does so when the caller says it has a
// real, disposable account to prove it against (TWS_PROVE_AWS=1, set by the scheduled AWS workflow), never because keys happen to be set.
function proofSkipReason(lab, env = process.env) {
  if (!lab || lab.requires !== 'aws' || env.TWS_PROVE_AWS === '1') return '';
  return 'needs a real AWS account, so it is proved by the scheduled AWS workflow (set TWS_PROVE_AWS=1 with a disposable account to run it here)';
}

module.exports = { labEnv, proofSkipReason, AWS_ENV };
