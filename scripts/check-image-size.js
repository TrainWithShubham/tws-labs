#!/usr/bin/env node
// Keeps the image light: fails when the built image is bigger than the budget in image-size-budget.json.
//   node scripts/check-image-size.js tws-labs:ci
// Growing the image on purpose is fine: raise maxMb in the same PR, say why in the PR, and add an Upgrade note.
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const MB = 1024 * 1024;
const BUDGET_FILE = path.join(__dirname, '..', 'image-size-budget.json');

function judge(sizeBytes, maxMb) {
  if (!Number.isFinite(sizeBytes) || sizeBytes <= 0) throw new Error(`could not read the image size (got ${sizeBytes})`);
  if (!Number.isFinite(maxMb) || maxMb <= 0) throw new Error(`the budget in image-size-budget.json must be a positive number of MB (got ${maxMb})`);
  const sizeMb = Math.round(sizeBytes / MB);
  const headroomMb = maxMb - sizeMb;
  const ok = headroomMb >= 0;
  const message = ok
    ? `image is ${sizeMb} MB, ${headroomMb} MB under the ${maxMb} MB budget`
    : `image is ${sizeMb} MB, ${-headroomMb} MB over the ${maxMb} MB budget. Trim it, or raise maxMb in image-size-budget.json and explain why in the PR`;
  return { ok, sizeMb, headroomMb, message };
}

function main(image) {
  if (!image) { console.error('usage: node scripts/check-image-size.js <image>'); return 2; }
  const size = Number(execFileSync('docker', ['image', 'inspect', '--format', '{{.Size}}', image], { encoding: 'utf8' }).trim());
  const { maxMb } = JSON.parse(fs.readFileSync(BUDGET_FILE, 'utf8'));
  const r = judge(size, maxMb);
  (r.ok ? console.log : console.error)(r.message);
  return r.ok ? 0 : 1;
}

if (require.main === module) process.exit(main(process.argv[2]));
module.exports = { judge };
