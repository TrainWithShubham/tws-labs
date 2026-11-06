// Page bodies for Standalone Linux Challenges. The shared chrome (header, frame) comes from ui.page().
const { esc, ext, rocket } = require('./ui');
const { renderMarkdown } = require('./markdown');
const { ASCII_BANNER } = require('./banner');

const crumb = (parts) => `<p class="crumb">${parts.map(([label, href]) => (href ? `<a href="${href}">${esc(label)}</a>` : `<span>${esc(label)}</span>`)).join('<i>/</i>')}</p>`;
const STAT = (id, label) => `<div class="stat-cell"><div class="stat-label">${label}</div><div class="stat-value" id="stat-${id}">&mdash;</div>${id === 'uptime' ? '' : `<div class="stat-bar"><div class="stat-bar-fill" id="stat-${id}-bar"></div></div>`}</div>`;

const CHALLENGE_SKILLS = Object.freeze({
  'file-directory-permissions': ['chmod', 'Permissions', 'Directory Traversal', 'Access Mode'],
  'users-groups-access': ['User Management', 'Groups', 'Sudo Policy', 'Access Control'],
  'the-missing-disk': ['lsblk', 'blkid', 'mkfs.ext4', 'Filesystem ID'],
  'mounting-filesystem-basics': ['fstab', 'UUID', 'Mount Points', 'Filesystem Options'],
  'process-service-fundamentals': ['ps', 'kill', 'Signals', 'Process Lifecycle'],
  'broken-deployment': ['File Permissions', 'Symlinks', 'Configuration', 'Deploy Locks'],
  'disk-pressure': ['Storage Forensics', 'Log Rotation', 'Inodes', 'Space Reclamation'],
  'process-resource': ['Process Trees', 'Signals', 'Memory & CPU', 'Telemetry'],
  'systemd-troubleshooting': ['Systemd Units', 'Journalctl', 'Unit Syntax', 'Daemon Reload'],
  'network-outage': ['Routing Tables', 'Default Gateway', 'Network Interfaces', 'Packet Tracing'],
});

function renderChallengeCards(items, domain) {
  return items.map((c) => {
    const levelName = c.level ? c.level.charAt(0).toUpperCase() + c.level.slice(1) : 'Beginner';
    return `
      <a class="challenge-row" href="/challenges/${esc(c.domain || domain)}/${esc(c.slug)}" data-lab="challenge:${esc(c.domain || domain)}/${esc(c.slug)}">
        <div class="challenge-row-left">
          <div class="challenge-row-header">
            <span class="challenge-id-badge">${esc(c.id)}</span>
            <h2 class="challenge-title">${esc(c.title)}</h2>
          </div>
          <p class="challenge-desc">${esc(c.summary)}</p>
        </div>
        <div class="challenge-row-right">
          <div class="challenge-row-meta">
            <span class="challenge-badge-level level-${esc(c.level)}">${esc(levelName)}</span>
            <span class="challenge-meta-item">${c.tasksCount} tasks<span data-lab-tasks="challenge:${esc(c.domain || domain)}/${esc(c.slug)}" data-total="${c.tasksCount}"></span></span>
            <span class="challenge-meta-sep" aria-hidden="true">&middot;</span>
            <span class="challenge-meta-item">${c.minutes} min</span>
          </div>
          <span class="challenge-start-btn">Start challenge &rarr;</span>
        </div>
      </a>`;
  }).join('');
}

function challengesLandingBody(domains, challengeLoader, selectedDomain = null) {
  const isSpecific = !!selectedDomain;
  const targetDomain = selectedDomain || 'linux';
  const domainMeta = domains.find((d) => d.id === targetDomain) || {
    id: targetDomain,
    title: 'Linux Troubleshooting',
    description: 'Real-world incident triage and system troubleshooting in simulated Linux environments.',
  };
  const challenges = challengeLoader.listChallenges(targetDomain) || [];

  const crumbs = isSpecific
    ? [['Challenges', '/challenges'], [domainMeta.title, '']]
    : [['Challenges', '']];

  const beginnerCount = challenges.filter((c) => c.level === 'beginner').length || 5;
  const intermediateCount = challenges.filter((c) => c.level === 'intermediate').length || 5;

  return `
    <div class="wrap track line-devops">
      ${crumb(crumbs)}
      <header class="challenges-hero">
        <div class="challenges-hero-top">
          <span class="challenges-eyebrow">Linux Engineering Challenges</span>
          <span class="challenges-status-pill"><span class="live-dot" aria-hidden="true"></span>10 Available</span>
        </div>
        <h1 class="challenges-hero-title">Master Linux through real incidents.</h1>
        <p class="challenges-hero-sub">Investigate. Troubleshoot. Fix. Validate.</p>
      </header>

      <section class="challenges-overview-row" aria-label="Level Overview">
        <a href="/challenges/${esc(targetDomain)}/level/beginner" class="overview-summary overview-beginner" aria-label="Beginner: ${beginnerCount} Challenges">
          <div class="overview-top">
            <span class="overview-icon" aria-hidden="true">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="4 17 10 11 4 5"></polyline><line x1="12" y1="19" x2="20" y2="19"></line></svg>
            </span>
            <span class="overview-level">Beginner</span>
          </div>
          <div class="overview-stat">
            <span class="overview-count">${beginnerCount}</span>
            <span class="overview-label">Challenges</span>
          </div>
        </a>

        <div class="overview-separator" aria-hidden="true"></div>

        <a href="/challenges/${esc(targetDomain)}/level/intermediate" class="overview-summary overview-intermediate" aria-label="Intermediate: ${intermediateCount} Challenges">
          <div class="overview-top">
            <span class="overview-icon" aria-hidden="true">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="12 2 2 7 12 12 22 7 12 2"></polygon><polyline points="2 17 12 22 22 17"></polyline><polyline points="2 12 12 17 22 12"></polyline></svg>
            </span>
            <span class="overview-level">Intermediate</span>
          </div>
          <div class="overview-stat">
            <span class="overview-count">${intermediateCount}</span>
            <span class="overview-label">Challenges</span>
          </div>
        </a>

        <div class="overview-separator" aria-hidden="true"></div>

        <div class="overview-summary overview-advanced is-dim" aria-label="Advanced: Coming soon">
          <div class="overview-top">
            <span class="overview-icon" aria-hidden="true">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"></polygon></svg>
            </span>
            <span class="overview-level">Advanced</span>
          </div>
          <div class="overview-stat">
            <span class="overview-count">Soon</span>
            <span class="overview-label">Coming soon</span>
          </div>
        </div>
      </section>

      <hr class="challenges-divider" />

      <section class="learning-path-section" aria-label="Learning Path">
        <h2 class="learning-path-title">Your learning path</h2>

        <div class="learning-path-list">
          <a href="/challenges/${esc(targetDomain)}/level/beginner" class="learning-path-row path-row-beginner">
            <div class="path-row-content">
              <div class="path-row-left">
                <span class="path-pill">01</span>
                <span class="path-name">Beginner</span>
              </div>
              <div class="path-row-right">
                <span class="path-action">Start here &rarr;</span>
              </div>
            </div>
            <div class="path-bar" aria-hidden="true"><div class="path-bar-fill"></div></div>
          </a>

          <a href="/challenges/${esc(targetDomain)}/level/intermediate" class="learning-path-row path-row-intermediate">
            <div class="path-row-content">
              <div class="path-row-left">
                <span class="path-pill">02</span>
                <span class="path-name">Intermediate</span>
              </div>
              <div class="path-row-right">
                <span class="path-action">Next level &rarr;</span>
              </div>
            </div>
            <div class="path-bar" aria-hidden="true"><div class="path-bar-fill"></div></div>
          </a>

          <div class="learning-path-row path-row-advanced is-dim">
            <div class="path-row-content">
              <div class="path-row-left">
                <span class="path-pill">03</span>
                <span class="path-name">Advanced</span>
              </div>
              <div class="path-row-right">
                <span class="path-action">Coming soon</span>
              </div>
            </div>
            <div class="path-bar" aria-hidden="true"><div class="path-bar-fill"></div></div>
          </div>
        </div>
      </section>
    </div>`;
}

function challengesLevelListingBody(domains, challengeLoader, domain, level) {
  const domainMeta = domains.find((d) => d.id === domain) || {
    id: domain,
    title: 'Linux Troubleshooting',
    description: 'Real-world incident triage and system troubleshooting in simulated Linux environments.',
  };
  const challenges = challengeLoader.listChallenges(domain) || [];
  const levelChallenges = challenges.filter((c) => c.level === level);
  const levelTitle = level.charAt(0).toUpperCase() + level.slice(1);

  const levelDescriptions = {
    beginner: 'Foundational triage: core command line diagnostics, file permissions, users and access control, storage discovery, mounting, and process management.',
    intermediate: 'Real-world incident response: multi-step troubleshooting, storage pressure, runaway processes, systemd failures, and network outages.',
  };
  const desc = levelDescriptions[level] || domainMeta.description;

  const crumbs = [
    ['Challenges', '/challenges'],
    [domainMeta.title, `/challenges/${domain}`],
    [levelTitle, ''],
  ];

  const cardsHtml = renderChallengeCards(levelChallenges, domain);

  return `
    <div class="wrap track line-devops">
      ${crumb(crumbs)}
      <div class="challenges-back-nav">
        <a href="/challenges/${esc(domain)}" class="challenges-back-link">&larr; Back to Learning Path</a>
      </div>
      <h1 class="page-title">${esc(levelTitle)} Challenges</h1>
      <p class="lede">${esc(desc)} Graded live on real machine state.</p>
      <div class="track-meta">
        <span class="meta">${levelChallenges.length} Challenges &middot; <span class="chip chip-live" aria-label="Status: Live"><span class="live-dot" aria-hidden="true"></span>LIVE</span></span>
      </div>

      <div class="challenge-list" role="list">
        ${cardsHtml}
      </div>
    </div>`;
}

function challengeDetailBody(challenge, domainMeta, cfg, nextChallenge) {
  const tasks = (challenge.steps || []).filter((s) => s.type === 'task');
  const tasksCount = tasks.length;

  const data = {
    type: 'challenge',
    domain: challenge.domain,
    challenge: challenge.slug,
    track: 'challenge:' + challenge.domain,
    lab: challenge.slug,
    title: challenge.title,
    trackUrl: '/challenges/' + challenge.domain,
    local: cfg.isLocal,
    gated: Boolean(!cfg.isLocal && (cfg.gated || !cfg.publicChallenges || !cfg.runtime || !cfg.runtime.isIsolated)),
    banner: ASCII_BANNER,
    links: [],
    resources: [], // Strictly no external documentation or reference links
    next: nextChallenge ? { href: `/challenges/${challenge.domain}/${nextChallenge.slug}`, title: nextChallenge.title } : null,
  };

  data.steps = (challenge.steps || []).map((step) => ({
    id: step.id,
    type: step.type,
    title: step.title,
    bodyHtml: renderMarkdown(step.body),
    hint: step.hint || '',
    hints: step.hints || [],
    success: step.success || '',
    hasSetup: Boolean(step.hasSetup),
    setup: Boolean(step.hasSetup || step.setupFile),
  }));

  const body = `
  <div class="lab-shell line-devops">
    <div class="tasks-pane">
      ${crumb([['Challenges', '/challenges'], [domainMeta.title, `/challenges/${challenge.domain}`], [challenge.title, '']])}
      <div class="tasks-header">
        <h1 class="lab-title"><span class="chip" style="margin-right:8px;vertical-align:middle">${esc(challenge.id)}</span>${esc(challenge.title)}</h1>
        <div class="lab-timer" id="lab-timer" title="Time left in this session"><span id="lab-timer-text">--:--</span></div>
      </div>
      <nav class="journey" id="journey" aria-label="Challenge progress">
        <span class="jline"><i></i><span id="jfill" style="display:none"></span></span>
        <span class="jticks" id="jticks"></span>
        <span class="jrocket" aria-hidden="true">${rocket()}</span>
      </nav>
      <div class="step-counter" id="step-counter"></div>
      <span id="task-current" hidden>0</span><span id="task-total" hidden>${tasksCount}</span>
      <div class="step-card">
        <div class="step-title" id="step-title"></div>
        <div class="step-body" id="step-body"></div>
        <div class="step-hint" id="step-hint" role="status"></div>
        <div class="step-footer">
          <button class="btn link" id="back-btn">&larr; Back</button>
          <button class="btn link" id="skip-btn">Skip &rarr;</button>
          <button class="btn link" id="hint-btn" hidden></button>
          <span class="spacer"></span>
          <button class="btn primary" id="action-btn">Check</button>
        </div>
      </div>
      <div class="lab-actions">
        <button class="btn" id="restart-btn" title="Start over with fresh files">Restart challenge</button>
        <button class="btn danger" id="end-btn">End challenge</button>
      </div>
    </div>
    <div class="terminal-pane">
      <div class="terminal-tab">
        <span id="status-pill" class="pill">starting</span> <span title="Tab goes to the shell; press Shift+Tab to leave the terminal">Terminal</span>
        <span class="terminal-links"><button class="fullscreen-btn" id="fs-btn" title="Fullscreen" aria-label="Fullscreen">&#x26F6;</button></span>
      </div>
      <form class="invite" id="invite" hidden autocomplete="off">
        <label for="invite-code">Invite code</label>
        <p id="invite-msg">This challenge runs on a shared cluster, so it needs an invite code.</p>
        <div class="invite-row"><input id="invite-code" type="password" spellcheck="false" autocapitalize="off" required /><button class="btn primary" type="submit">Start</button></div>
      </form>
      <div id="term"></div>
    </div>
  </div>
  <div class="stats-box" id="stats-box">${STAT('cpu', 'CPU')}${STAT('mem', 'Memory')}${STAT('uptime', 'Uptime')}<div class="stats-note-cell">${esc(cfg.ownerNote || '')}</div></div>`;

  const json = JSON.stringify(data).replace(/</g, '\\u003c');
  const scripts = `<link rel="stylesheet" href="/xterm/xterm.css" />
  <script id="lab-data" type="application/json">${json}</script>
  <script src="/xterm/xterm.js"></script><script src="/xterm/addon-fit.js"></script><script src="/progress.js"></script><script src="/lab.js"></script>`;

  return { body, scripts };
}

module.exports = {
  CHALLENGE_SKILLS,
  challengesLandingBody,
  challengesCatalogueBody: challengesLandingBody,
  challengesLevelListingBody,
  challengeDetailBody,
};
