// Reads the community-contributed content in labs/ and validates its shape.
//   labs/<track>/track.yaml                  title, description, labs: [lab ids in order]
//   labs/<track>/<lab>/lab.yaml              title, level, minutes, summary, steps: [...]
//   labs/<track>/<lab>/setup.sh              optional: seeds the learner's fresh home
//   labs/<track>/<lab>/checks/<step>.sh      grading script for a task step
//   labs/<track>/<lab>/solutions/<step>.sh   one command per line; proves the lab is solvable
const fs = require('fs');
const path = require('path');
const { httpsUrl, readYaml } = require('./site');
const { renderMarkdown } = require('./markdown');

const ID_RE = /^[a-z0-9][a-z0-9-]{0,48}$/;
const LEVELS = ['beginner', 'intermediate', 'advanced'];

function loadLab(labsDir, trackId, labId, problems) {
  const dir = path.join(labsDir, trackId, labId);
  const file = path.join(dir, 'lab.yaml');
  const raw = readYaml(file, problems);
  if (!raw) return null;
  const where = `${trackId}/${labId}`;
  const bad = (msg) => { problems.push(`${where}: ${msg}`); return null; };

  if (typeof raw.title !== 'string' || !raw.title.trim()) return bad('title is required');
  if (!LEVELS.includes(raw.level)) return bad(`level must be one of ${LEVELS.join(', ')}`);
  if (!Array.isArray(raw.steps) || raw.steps.length === 0) return bad('steps must be a non-empty list');
  // A lab that needs the learner's own cloud account says so; it then runs only on their machine (see src/lab-env.js).
  if (raw.requires !== undefined && raw.requires !== 'aws') return bad('requires must be "aws" (or left out)');

  const seen = new Set();
  const steps = [];
  for (const [n, s] of raw.steps.entries()) {
    const tag = `step ${n + 1}`;
    if (!s || !ID_RE.test(s.id || '')) return bad(`${tag}: id must match ${ID_RE}`);
    if (seen.has(s.id)) return bad(`${tag}: duplicate id "${s.id}"`);
    seen.add(s.id);
    if (s.type !== 'lesson' && s.type !== 'task') return bad(`step "${s.id}": type must be lesson or task`);
    if (typeof s.title !== 'string' || typeof s.body !== 'string') return bad(`step "${s.id}": title and body are required`);
    if (s.local_body !== undefined && typeof s.local_body !== 'string') return bad(`step "${s.id}": local_body must be text`);
    if (s.success !== undefined && (typeof s.success !== 'string' || s.success.length > 100)) return bad(`step "${s.id}": success must be text of at most 100 characters`);
    // A hint is one nudge or a list of up to three tiers, gentle to specific; `hint` stays the first one.
    let hints = [];
    if (s.hint !== undefined && s.hint !== null && s.hint !== '') {
      hints = Array.isArray(s.hint) ? s.hint : [s.hint];
      if (typeof s.hint !== 'string' && !Array.isArray(s.hint)) return bad(`step "${s.id}": hint: must be text or a list of text`);
      if (hints.length > 3) return bad(`step "${s.id}": hint: at most 3 tiers`);
      if (hints.some((h) => typeof h !== 'string' || !h.trim())) return bad(`step "${s.id}": hint: every tier must be non-empty text`);
      if (hints.some((h) => h.length > 300)) return bad(`step "${s.id}": hint: each tier is at most 300 characters`);
    }
    const step = {
      id: s.id, type: s.type, title: s.title, body: s.body, bodyHtml: renderMarkdown(s.body), hint: hints[0] || '', hints,
      // Optional confirmation shown in green when the task's check passes (default: "Correct. Step complete.").
      success: s.success || '',
      // Optional wording for the laptop profile (e.g. "there is no cluster here"); same checks.
      localBodyHtml: s.local_body ? renderMarkdown(s.local_body) : null,
    };
    if (s.type === 'task') {
      step.checkFile = path.join(dir, 'checks', `${s.id}.sh`);
      step.solutionFile = path.join(dir, 'solutions', `${s.id}.sh`);
      if (!fs.existsSync(step.checkFile)) return bad(`task "${s.id}": missing checks/${s.id}.sh`);
      if (!fs.existsSync(step.solutionFile)) return bad(`task "${s.id}": missing solutions/${s.id}.sh`);
      // Optional starting state for a learner who skipped ahead: setup/<task>.sh. A leading "# cwd: folder" line says where their shell
      // should be for this task (a plain folder under home), because a script cannot change the directory of a shell that is already open.
      step.setupFile = '';
      step.setupCwd = '';
      step.skipNote = '';
      const setupFile = path.join(dir, 'setup', `${s.id}.sh`);
      const noSkip = fs.existsSync(setupFile) && fs.readFileSync(setupFile, 'utf8').split('\n').slice(0, 5).map((l) => /^#\s*no-skip:\s*(.+?)\s*$/.exec(l)).find(Boolean);
      if (noSkip) step.skipNote = noSkip[1];   // a marker, not a script: this task really builds on an earlier one
      else if (fs.existsSync(setupFile)) {
        step.setupFile = setupFile;
        const m = fs.readFileSync(setupFile, 'utf8').split('\n').slice(0, 5).map((l) => /^#\s*cwd:\s*(.*?)\s*$/.exec(l)).find(Boolean);
        if (m) {
          if (!/^[A-Za-z0-9._-]+(\/[A-Za-z0-9._-]+)*$/.test(m[1]) || m[1].split('/').some((x) => x === '..' || x === '.')) return bad(`setup/${s.id}.sh: cwd must be a plain relative folder under home, like myrepo or src/app`);
          step.setupCwd = m[1];
        }
      }
    }
    steps.push(step);
  }
  const taskIds = new Set(steps.filter((x) => x.type === 'task').map((x) => x.id));
  const setupDir = path.join(dir, 'setup');
  if (fs.existsSync(setupDir)) {
    for (const f of fs.readdirSync(setupDir).filter((n) => n.endsWith('.sh'))) {
      if (!taskIds.has(f.slice(0, -3))) return bad(`setup/${f}: no task called "${f.slice(0, -3)}" in lab.yaml`);
    }
  }
  const links = [];
  for (const l of Array.isArray(raw.links) ? raw.links : []) {
    if (!l || typeof l.title !== 'string' || !httpsUrl(l.url)) return bad('links[] need a title and an https:// url');
    links.push({ title: l.title, url: l.url });
  }
  const resources = [];
  for (const r of Array.isArray(raw.resources) ? raw.resources : []) {
    if (!r || typeof r.title !== 'string' || !httpsUrl(r.url)) return bad('resources[] need a title and an https:// url');
    resources.push({ title: r.title, url: r.url, desc: r.desc || '' });
  }
  return {
    track: trackId, id: labId, dir, title: raw.title, level: raw.level,
    minutes: Number(raw.minutes) || 10, summary: raw.summary || '', requires: raw.requires || '', steps, links, resources,
  };
}

function loadCatalog(labsDir) {
  const problems = [];
  const tracks = [];
  let entries = [];
  try { entries = fs.readdirSync(labsDir, { withFileTypes: true }); } catch (e) { problems.push(`${labsDir}: ${e.message}`); }
  for (const ent of entries.filter((e) => e.isDirectory()).sort((a, b) => a.name.localeCompare(b.name))) {
    if (!ID_RE.test(ent.name)) { problems.push(`${ent.name}: track folder name must match ${ID_RE}`); continue; }
    const raw = readYaml(path.join(labsDir, ent.name, 'track.yaml'), problems);
    if (!raw) continue;
    if (typeof raw.title !== 'string' || !Array.isArray(raw.labs)) { problems.push(`${ent.name}/track.yaml: title and labs[] are required`); continue; }
    const labs = [];
    for (const labId of raw.labs) {
      if (!ID_RE.test(String(labId))) { problems.push(`${ent.name}/track.yaml: bad lab id "${labId}"`); continue; }
      const lab = loadLab(labsDir, ent.name, String(labId), problems);
      if (lab) labs.push(lab);
    }
    let video = null;
    if (raw.video) {
      if (httpsUrl(raw.video.url) && typeof raw.video.title === 'string') video = { title: raw.video.title, url: raw.video.url, note: raw.video.note || '' };
      else problems.push(`${ent.name}/track.yaml: video needs a title and an https:// url`);
    }
    tracks.push({ id: ent.name, order: Number.isFinite(raw.order) ? raw.order : 100, title: raw.title, description: raw.description || '', video, labs });
  }
  // Learning order first (track.yaml `order:`), then alphabetical.
  tracks.sort((a, b) => a.order - b.order || a.title.localeCompare(b.title));
  return { tracks, problems };
}

module.exports = { loadCatalog, ID_RE, LEVELS };
