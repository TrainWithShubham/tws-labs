// assertBrandedPage(html, active): the one definition of "this page has the TWS Labs chrome".
// Both apps' integration tests call it on their pages, so header drift fails CI in whichever app drifted.
const assert = require('node:assert/strict');

function assertBrandedPage(html, active, where = '') {
  assert.match(html, /<link rel="stylesheet" href="\/app.css" \/>/, `${where}: app.css not linked`);
  assert.match(html, /<img class="logo-mark" src="\/logo\/tws-labs-logo\.png"/, `${where}: logo missing`);
  const nav = html.match(/<nav class="tabs"[^>]*>(.*?)<\/nav>/s);
  assert.ok(nav, `${where}: tabs missing`);
  assert.deepEqual([...nav[1].matchAll(/>([A-Za-z]+)<\/a>/g)].map((m) => m[1]), ['Labs', 'Challenges', 'Videos', 'Roadmap'], `${where}: tab set`);
  assert.deepEqual([...nav[1].matchAll(/is-active"[^>]*>([A-Za-z]+)</g)].map((m) => m[1]), [active], `${where}: active tab`);
  assert.match(html, /class="btn-yt" href="https:\/\/www\.youtube\.com\/[^"]*"[^>]*rel="noopener noreferrer"/, `${where}: Subscribe button`);
}

module.exports = { assertBrandedPage };
