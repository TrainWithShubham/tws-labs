// "Done wrong" and "done differently" fixtures for a lab's checks, in labs/<track>/<lab>/cases/<task>/<name>.sh:
//   <name>.sh      leaves a wrong-but-plausible state; the task's check must FAIL on it
//   ok-<name>.sh   a valid alternative to the solution; the check must PASS on it
// Written like solutions (one command per line). The validator replays the lab up to that task in a fresh sandbox, runs the case, and
// grades it. This is how a check proves it is neither too lax (accepts a near miss) nor too strict (rejects a valid way).
const fs = require('fs');
const path = require('path');

const NAME_RE = /^[a-z0-9][a-z0-9-]*$/;

function loadCases(labDir, taskIds) {
  const root = path.join(labDir, 'cases');
  const problems = [];
  const cases = [];
  if (!fs.existsSync(root)) return { cases, problems };
  for (const task of fs.readdirSync(root, { withFileTypes: true }).filter((e) => e.isDirectory()).map((e) => e.name).sort()) {
    if (!taskIds.includes(task)) { problems.push(`cases/${task}: no task called "${task}" in lab.yaml`); continue; }
    for (const file of fs.readdirSync(path.join(root, task)).filter((f) => f.endsWith('.sh')).sort()) {
      const name = file.slice(0, -3);
      const where = `cases/${task}/${file}`;
      if (!NAME_RE.test(name)) { problems.push(`${where}: case names use a-z, 0-9 and - (ok- marks a valid alternative)`); continue; }
      const text = fs.readFileSync(path.join(root, task, file), 'utf8');
      const lines = text.split('\n').map((l) => l.trim()).filter((l) => l && !l.startsWith('#'));
      if (!lines.length) { problems.push(`${where}: no commands`); continue; }
      const bad = lines.find((l) => /<<-?\s*['"]?\w+/.test(l) || /\\$/.test(l));
      if (bad) { problems.push(`${where}: one command per line (no heredocs or line continuations): ${bad.slice(0, 40)}`); continue; }
      cases.push({ task, name, file: path.join(root, task, file), lines, expect: name.startsWith('ok-') ? 'pass' : 'fail' });
    }
  }
  return { cases, problems };
}

module.exports = { loadCases };
