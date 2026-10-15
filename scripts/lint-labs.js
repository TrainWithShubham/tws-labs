#!/usr/bin/env node
// Fast static checks for labs - no Docker, no Linux needed:  npm run lab:lint [track/lab] [--strict] [--notes] [--json]
//   - everything the engine's loader, the house-style linter and the roadmap validator already report
//   - every script parses (bash -n); solutions are one command per line; checks source the helpers,
//     print a nudge when they fail, and do not change the learner's files
//   - a task whose check is the same as another lab's check (a repeated task) is flagged
//   - advice ("note", never fails a build, even with --strict): no success message, a check that only reads the typed
//     history, a hint that is too short or repeats the command from the task, labs over 15 minutes
// `npm run lab:check` runs this and then the real proof (each check fails before its solution and passes after).
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const { loadCatalog } = require('../src/loader');
const { loadRoadmap } = require('../src/roadmap');
const { lintLab } = require('../src/lint');

const MUTATORS = /(^|[;&|(]\s*)(rm|mv|cp|touch|chmod|chown|mkdir|tee|sed\s+-i)\s/;

// Two checks are "the same task" when they match after dropping comments, messages, numbers and spacing.
function normalise(text) {
  return text.split('\n')
    .map((l) => l.replace(/#.*$/, '').replace(/fail\s+"[^"]*"/g, 'fail').replace(/[0-9]+/g, 'N').replace(/\s+/g, ' ').trim())
    .filter((l) => l && !/^\.\s+"?\$LAB_LIB"?$/.test(l))
    .join('\n');
}

const ADVICE = { softMinutes: 15, minHint: 10, minCommand: 6 };

// A check that never looks at the machine, only at what was typed, passes for the right command with the wrong result.
function onlyReadsHistory(check) {
  const lines = check.split('\n').map((l) => l.replace(/#.*$/, '').trim()).filter((l) => l && !/^(\.|source)\s+"?\$LAB_LIB"?$/.test(l));
  return lines.some((l) => /^ran(_re)?\b/.test(l)) && lines.every((l) => /^(ran(_re)?|fail)\b/.test(l));
}

function adviseTask(step) {
  const out = [];
  if (!step.success) out.push(`task "${step.id}" has no success: message (a short confirmation shown when the check passes)`);
  const hint = String(step.hint || '').trim();
  if (hint && hint.length < ADVICE.minHint) out.push(`step "${step.id}": the hint is only ${hint.length} chars: a hint should nudge the learner towards the idea`);
  const commands = [...String(step.body || '').matchAll(/`([^`\n]+)`/g)].map((m) => m[1].trim()).filter((c) => c.length >= ADVICE.minCommand);
  if (hint && commands.some((c) => hint.includes(c))) out.push(`step "${step.id}": the hint repeats the command from the task: point at the idea (a flag, a man page) instead of the answer`);
  return out;
}

function bashSyntax(file) {
  const r = spawnSync('bash', ['-n', file], { encoding: 'utf8' });
  if (r.error) return r.error.code === 'ENOENT' ? null : r.error.message;
  return r.status === 0 ? '' : (r.stderr.trim().split('\n')[0] || 'syntax error').replace(file, path.basename(file));
}

function lintLabs({ labsDir, only } = {}) {
  const findings = [];
  const add = (lab, level, message) => findings.push({ lab, level, message });
  const catalog = loadCatalog(labsDir);
  catalog.problems.forEach((p) => add('catalog', 'error', p));
  loadRoadmap(catalog, path.join(labsDir, 'roadmap.json')).problems.forEach((p) => add('roadmap', 'error', p));

  const seen = new Map();   // normalised check -> "track/lab/step"
  const owner = [];
  let bashMissing = false;
  for (const track of catalog.tracks) {
    for (const lab of track.labs) {
      const id = `${track.id}/${lab.id}`;
      for (const step of lab.steps.filter((s) => s.type === 'task')) {
        const check = fs.readFileSync(step.checkFile, 'utf8');
        const key = normalise(check);
        if (key.split('\n').length >= 2) {   // one-line checks ("cd into the repo") legitimately repeat
          const first = seen.get(key);
          if (first && !first.startsWith(`${id}/`)) owner.push({ id, step: step.id, other: first });
          else if (!first) seen.set(key, `${id}/${step.id}`);
        }
      }
    }
  }

  for (const track of catalog.tracks) {
    for (const lab of track.labs) {
      const id = `${track.id}/${lab.id}`;
      if (only && only !== id) continue;
      lintLab(lab).forEach((w) => add(id, 'warn', `style: ${w}`));
      if (lab.minutes > ADVICE.softMinutes) add(id, 'info', `${lab.minutes} minutes: labs of ${5}-${ADVICE.softMinutes} minutes finish more often (the limit is 20)`);
      // the scaffold's two sample tasks must be replaced, not shipped
      for (const [sid, sample] of [['create-file', 'Create a file'], ['list-files', 'Look around']]) {
        if (lab.steps.some((s) => s.id === sid && s.title === sample)) add(id, 'warn', `the template's sample task "${sid}" is still here: replace it with your own task (and delete its checks/solutions files)`);
      }
      const scripts = [];
      if (fs.existsSync(path.join(lab.dir, 'setup.sh'))) scripts.push({ file: path.join(lab.dir, 'setup.sh'), what: 'setup.sh' });
      for (const step of lab.steps.filter((s) => s.type === 'task')) {
        const check = fs.readFileSync(step.checkFile, 'utf8');
        const solution = fs.readFileSync(step.solutionFile, 'utf8');
        scripts.push({ file: step.checkFile, what: `checks/${step.id}.sh` }, { file: step.solutionFile, what: `solutions/${step.id}.sh` });
        adviseTask(step).forEach((m) => add(id, 'info', m));
        if (onlyReadsHistory(check)) add(id, 'info', `checks/${step.id}.sh only reads the command history: it grades what was typed, not what happened. Check the resulting state (a file, a process, a repo) where you can`);
        if (!/(^|\n)\s*(\.|source)\s+"?\$LAB_LIB"?/.test(check)) add(id, 'error', `checks/${step.id}.sh must start with  . "$LAB_LIB"  (it provides fail, ran, file_has ...)`);
        if (!/\bfail\b|exit\s+1/.test(check)) add(id, 'error', `checks/${step.id}.sh never fails: use  fail "what is still missing"`);
        else if (!/\bfail\s+["']/.test(check)) add(id, 'warn', `checks/${step.id}.sh: give the learner a nudge with  fail "message"`);
        for (const line of check.split('\n')) {
          if (MUTATORS.test(line.replace(/#.*$/, '').replace(/\$\([^)]*\)/g, ''))) { add(id, 'warn', `checks/${step.id}.sh changes files (${line.trim().slice(0, 40)}): checks must be read-only`); break; }
        }
        for (const line of solution.split('\n')) {
          if (/<<-?\s*['"]?\w+/.test(line) || /\\\s*$/.test(line)) { add(id, 'error', `solutions/${step.id}.sh: one command per line (no heredocs or line continuations): ${line.trim().slice(0, 40)}`); break; }
        }
        const dup = owner.find((o) => o.id === id && o.step === step.id);
        if (dup) add(id, 'warn', `task "${step.id}" has the same check as ${dup.other}: avoid repeating a task that exists in another lab`);
      }
      for (const s of scripts) {
        const err = bashSyntax(s.file);
        if (err === null) { bashMissing = true; break; }
        if (err) add(id, 'error', `${s.what}: ${err}`);
      }
    }
  }
  if (bashMissing) add('tools', 'warn', 'bash not found: script syntax was not checked (Git Bash or WSL provides it on Windows)');
  return findings;
}

function main() {
  const args = process.argv.slice(2);
  const strict = args.includes('--strict');
  const asJson = args.includes('--json');
  const only = args.find((a) => !a.startsWith('--'));
  const labsDir = process.env.LABS_DIR || path.join(__dirname, '..', 'labs');
  const findings = lintLabs({ labsDir, only });
  // the naming check reads `git ls-files`, so it only runs inside a git checkout
  const hygiene = fs.existsSync(path.join(__dirname, '..', '.git')) ? spawnSync(process.execPath, [path.join(__dirname, 'check-hygiene.js')], { encoding: 'utf8' }) : { status: 0 };
  if (hygiene.status !== 0) findings.push({ lab: 'hygiene', level: 'error', message: (hygiene.stderr || hygiene.stdout).trim().split('\n').slice(0, 3).join(' ') });
  const errors = findings.filter((f) => f.level === 'error').length;
  const warns = findings.filter((f) => f.level === 'warn').length;
  if (asJson) console.log(JSON.stringify(findings, null, 2));
  else {
    const tag = { error: 'ERROR', warn: 'warn ', info: 'note ' };
    const showNotes = args.includes('--notes') || !!only;   // 150+ notes across the shipped labs: list them on request, or for the one lab you are working on
    findings.filter((f) => showNotes || f.level !== 'info').forEach((f) => console.log(`${tag[f.level]} ${f.lab}: ${f.message}`));
    const notes = findings.filter((f) => f.level === 'info').length;
    const tail = notes ? ` ${notes} note(s) are advice and never fail the build${showNotes ? '' : ' (npm run lab:lint -- --notes lists them)'}.` : '';
    console.log(errors || warns ? `\n${errors} error(s), ${warns} warning(s)${strict && warns ? ' (--strict: warnings fail)' : ''}.${tail}` : `Labs look good (static checks).${tail}`);
  }
  process.exit(errors || (strict && warns) ? 1 : 0);
}

if (require.main === module) main();
module.exports = { lintLabs, normalise };
