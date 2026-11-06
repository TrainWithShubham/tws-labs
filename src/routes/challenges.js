const { json, send } = require('../http');
const pages = require('../pages');
const challengePages = require('../challenge-pages');
const { CHALLENGE_REGISTRY } = require('../challenge-loader');

// Standalone challenge catalogue and execution routes.
module.exports = function challengeRoutes(router, d) {
  const { cfg, page, challengeLoader } = d;

  // GET /challenges - Standalone challenges catalogue / landing page
  router.get('/challenges', (req, res) => {
    const domains = challengeLoader.getDomains();
    const body = challengePages.challengesLandingBody(domains, challengeLoader);
    send(res, 200, 'text/html', page('challenges', 'Challenges', body));
  });

  // GET /challenges/:domain/level/:level - Level-specific challenge listing
  router.get(/^\/challenges\/([a-z0-9-]+)\/level\/([a-z0-9-]+)$/, (req, res, { m }) => {
    const domain = m[1];
    const level = m[2];
    if (!CHALLENGE_REGISTRY[domain]) {
      return send(res, 404, 'text/html', page('challenges', 'Not found', pages.notFoundBody()));
    }
    const VALID_LEVELS = new Set(['beginner', 'intermediate']);
    if (!VALID_LEVELS.has(level)) {
      return send(res, 404, 'text/html', page('challenges', 'Not found', pages.notFoundBody()));
    }
    const domains = challengeLoader.getDomains();
    const domainMeta = domains.find((dom) => dom.id === domain) || { id: domain, title: `${domain} Challenges` };
    const levelTitle = level.charAt(0).toUpperCase() + level.slice(1);
    const body = challengePages.challengesLevelListingBody(domains, challengeLoader, domain, level);
    send(res, 200, 'text/html', page('challenges', `${domainMeta.title} - ${levelTitle}`, body, '<script src="/progress.js"></script>'));
  });

  // GET /challenges/:domain - Domain-specific challenges landing page
  router.get(/^\/challenges\/([a-z0-9-]+)$/, (req, res, { m }) => {
    const domain = m[1];
    if (!CHALLENGE_REGISTRY[domain]) {
      return send(res, 404, 'text/html', page('challenges', 'Not found', pages.notFoundBody()));
    }
    const domains = challengeLoader.getDomains();
    const domainMeta = domains.find((dom) => dom.id === domain) || { id: domain, title: `${domain} Challenges` };
    const body = challengePages.challengesLandingBody(domains, challengeLoader, domain);
    send(res, 200, 'text/html', page('challenges', domainMeta.title, body));
  });

  // GET /challenges/:domain/:slug - Individual challenge detail / interactive terminal page
  router.get(/^\/challenges\/([a-z0-9-]+)\/([a-z0-9-]+)$/, (req, res, { m }) => {
    const domain = m[1];
    const slug = m[2];
    if (!CHALLENGE_REGISTRY[domain]) {
      return send(res, 404, 'text/html', page('challenges', 'Not found', pages.notFoundBody()));
    }
    const challenge = challengeLoader.getChallengeInternal(domain, slug);
    if (!challenge) {
      return send(res, 404, 'text/html', page('challenges', 'Not found', pages.notFoundBody()));
    }

    const domains = challengeLoader.getDomains();
    const domainMeta = domains.find((dom) => dom.id === domain) || { id: domain, title: `${domain} Challenges` };

    const entries = CHALLENGE_REGISTRY[domain] || [];
    const idx = entries.findIndex((e) => e.slug === slug);
    const nextEntry = idx >= 0 && idx < entries.length - 1 ? entries[idx + 1] : null;
    const nextChallenge = nextEntry ? challengeLoader.getChallenge(domain, nextEntry.slug) : null;

    const { body, scripts } = challengePages.challengeDetailBody(challenge, domainMeta, cfg, nextChallenge);
    send(res, 200, 'text/html', page('challenges', challenge.title, body, scripts), { 'Cache-Control': 'no-store' });
  });

  // API Routes:
  // GET /api/challenges - List all challenge domains
  router.get('/api/challenges', (req, res) => {
    const domains = challengeLoader.getDomains();
    json(res, 200, { domains });
  });

  // GET /api/challenges/:domain - List challenges for a specific domain
  router.get(/^\/api\/challenges\/([a-z0-9-]+)$/, (req, res, { m }) => {
    const domain = m[1];
    const challenges = challengeLoader.listChallenges(domain);
    if (!challenges) {
      return json(res, 404, { error: 'unknown domain' });
    }
    json(res, 200, {
      domain,
      challenges,
    });
  });

  // GET /api/challenges/:domain/:slug - Get detail metadata for a specific challenge
  router.get(/^\/api\/challenges\/([a-z0-9-]+)\/([a-z0-9-]+)$/, (req, res, { m }) => {
    const domain = m[1];
    const slug = m[2];
    const challenge = challengeLoader.getChallenge(domain, slug);
    if (!challenge) {
      return json(res, 404, { error: 'unknown challenge' });
    }
    json(res, 200, challenge);
  });
};
