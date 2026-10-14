// The roadmap: which topics exist on each line (DevOps / Cloud / AI) and how far along each is.
// labs/roadmap.json is the single source of truth for the syllabus and each topic's status. It is
// validated against the real lab catalog, so the page can never claim a topic is live without labs
// behind it, and no lab can silently go missing from the map.
const fs = require('fs');
const path = require('path');
const { httpsUrl } = require('./site');

const DEFAULT_FILE = path.join(__dirname, '..', 'labs', 'roadmap.json');
const STATUSES = ['live', 'building', 'next', 'later'];
const ID_RE = /^[a-z][a-z0-9-]{0,40}$/;

function readJson(file, problems) {
  try { return JSON.parse(fs.readFileSync(file, 'utf8')); } catch (e) {
    problems.push(`${path.basename(file)}: ${e.code === 'ENOENT' ? 'file not found' : e.message.split('\n')[0]}`);
    return null;
  }
}

// Where clicking a station goes: straight to a lab when the topic has exactly one, else to its track page.
function hrefFor(labs) {
  if (!labs.length) return '';
  if (labs.length === 1) return `/lab/${labs[0].track}/${labs[0].id}`;
  return `/t/${labs[0].track}`;
}

function loadRoadmap(catalog, file = DEFAULT_FILE) {
  const problems = [];
  const out = { source: null, domains: [], problems };
  const raw = readJson(file, problems);
  if (!raw) return out;
  const bad = (msg) => problems.push(`roadmap.json: ${msg}`);

  const allLabs = new Map();                                  // "track/lab" -> catalog lab
  for (const t of catalog.tracks) for (const l of t.labs) allLabs.set(`${t.id}/${l.id}`, { track: t.id, trackTitle: t.title, ...l });
  const covered = new Set();
  const domainIds = new Set((Array.isArray(raw.domains) ? raw.domains : []).map((d) => d && d.id));
  const topicIds = new Set();

  if (raw.source && typeof raw.source === 'object') out.source = raw.source;
  if (!Array.isArray(raw.domains) || !raw.domains.length) { bad('domains[] is required'); return out; }

  for (const d of raw.domains) {
    if (!d || !ID_RE.test(String(d.id || '')) || typeof d.title !== 'string') { bad('every domain needs an id (a-z, 0-9, -) and a title'); continue; }
    const domain = { id: d.id, title: d.title, tagline: typeof d.tagline === 'string' ? d.tagline : '', topics: [], capstones: [] };
    for (const t of Array.isArray(d.topics) ? d.topics : []) {
      const where = `${d.id}/${t && t.id}`;
      const problemsBefore = problems.length;
      if (!t || !ID_RE.test(String(t.id || '')) || typeof t.title !== 'string') { bad(`${d.id}: every topic needs an id and a title`); continue; }
      if (topicIds.has(t.id)) { bad(`${where}: duplicate topic id`); continue; }
      topicIds.add(t.id);
      if (!STATUSES.includes(t.status)) { bad(`${where}: status must be one of ${STATUSES.join(', ')}`); continue; }
      if (t.relevance !== undefined && !(Number.isFinite(t.relevance) && t.relevance >= 0 && t.relevance <= 100)) { bad(`${where}: relevance must be 0-100`); continue; }
      if (t.video && !(typeof t.video.title === 'string' && httpsUrl(t.video.url))) { bad(`${where}: video needs a title and an https:// url`); continue; }

      // resolve real content: `track` = every lab of that track, `labs` = explicit "track/lab" keys
      const refs = [];
      if (t.track !== undefined) {
        const track = catalog.tracks.find((x) => x.id === t.track);
        if (!track) bad(`${where}: unknown track "${t.track}"`); else track.labs.forEach((l) => refs.push(`${track.id}/${l.id}`));
      }
      for (const key of Array.isArray(t.labs) ? t.labs : []) {
        if (allLabs.has(key)) refs.push(key); else bad(`${where}: unknown lab "${key}"`);
      }
      const labs = refs.map((k) => { covered.add(k); return allLabs.get(k); });
      if (t.status === 'live' && !labs.length) bad(`${where}: status is "live" but no lab is attached (add "track" or "labs")`);
      if (t.status !== 'live' && labs.length) bad(`${where}: has labs attached but status is "${t.status}" - set it to "live"`);

      // A topic with any problem is dropped (and reported): better a missing station than one that lies.
      if (problems.length > problemsBefore) continue;
      domain.topics.push({
        id: t.id, title: t.title, short: typeof t.short === 'string' ? t.short : t.title, status: t.status, relevance: t.relevance ?? null,
        subtopics: (Array.isArray(t.subtopics) ? t.subtopics : []).filter((s) => typeof s === 'string').slice(0, 8),
        video: t.video ? { title: t.video.title, url: t.video.url } : null,
        also: (Array.isArray(t.also) ? t.also : []).filter((a) => domainIds.has(a) && a !== d.id),
        labs, href: hrefFor(labs),
      });
    }
    for (const c of Array.isArray(d.capstones) ? d.capstones : []) {
      if (c && typeof c.title === 'string') domain.capstones.push({ title: c.title, stack: typeof c.stack === 'string' ? c.stack : '' });
    }
    out.domains.push(domain);
  }
  for (const key of allLabs.keys()) if (!covered.has(key)) bad(`lab "${key}" is not on the roadmap - add it to a topic so learners can find it`);
  return out;
}

// What the home-page map shows: everything that exists or is coming up next. "Later" lives on the Roadmap page.
const onMap = (domain) => domain.topics.filter((t) => t.status !== 'later');
const later = (domain) => domain.topics.filter((t) => t.status === 'later');

module.exports = { loadRoadmap, onMap, later, STATUSES, DEFAULT_FILE };
