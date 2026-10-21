const test = require('node:test');
const assert = require('node:assert/strict');
const { renderMarkdown } = require('../../src/markdown');

test('raw HTML and script tags from lab content are escaped, never emitted', () => {
  const html = renderMarkdown('<script>alert(1)</script> and <img src=x onerror=alert(1)>');
  assert.ok(!html.includes('<script'));
  assert.ok(!html.includes('<img'));
  assert.match(html, /&lt;script&gt;/);
});

test('inline code, bold, links and lists render', () => {
  const html = renderMarkdown('Run `ls -l` and **read** [docs](https://example.com).\n\n- one\n- two');
  assert.match(html, /<code>ls -l<\/code>/);
  assert.match(html, /<strong>read<\/strong>/);
  assert.match(html, /<a href="https:\/\/example\.com" target="_blank" rel="noopener noreferrer">docs<\/a>/);
  assert.match(html, /<ul><li>one<\/li><li>two<\/li><\/ul>/);
});

test('javascript: links are not turned into anchors', () => {
  assert.ok(!renderMarkdown('[x](javascript:alert(1))').includes('<a '));
});

test('code inside backticks is not re-interpreted as bold/links, and fences keep content literal', () => {
  assert.match(renderMarkdown('`**not bold**`'), /<code>\*\*not bold\*\*<\/code>/);
  assert.match(renderMarkdown('```\necho "<b>"\n```'), /<pre><code>echo &quot;&lt;b&gt;&quot;<\/code><\/pre>/);
});

test('a quote in a link cannot break out of the href attribute', () => {
  const html = renderMarkdown('[x](https://a.com/"onmouseover="alert(1))');
  assert.ok(!/onmouseover="/.test(html));
});

test('*italic* and _italic_ render as emphasis, and bold still works around them', () => {
  assert.equal(renderMarkdown('Every call is made *as someone*.'), '<p>Every call is made <em>as someone</em>.</p>');
  assert.equal(renderMarkdown('A _gentle_ nudge and **bold** text'), '<p>A <em>gentle</em> nudge and <strong>bold</strong> text</p>');
  assert.doesNotThrow(() => renderMarkdown('***both*** and ** ** and * *'), 'odd emphasis never crashes');
});

test('things that look like emphasis but are not stay literal: globs, snake_case, lone stars, code', () => {
  assert.equal(renderMarkdown('Delete *.log and *.tmp files'), '<p>Delete *.log and *.tmp files</p>');
  assert.equal(renderMarkdown('set my_var_name and other_var'), '<p>set my_var_name and other_var</p>');
  assert.equal(renderMarkdown('2 * 3 = 6 and a * b'), '<p>2 * 3 = 6 and a * b</p>');
  assert.equal(renderMarkdown('Run `echo *.txt` now'), '<p>Run <code>echo *.txt</code> now</p>');
  assert.equal(renderMarkdown('```\necho *not italic*\n```'), '<pre><code>echo *not italic*</code></pre>');
});

test('emphasis can never inject markup', () => {
  const html = renderMarkdown('*<script>alert(1)</script>* and _<img src=x onerror=1>_');
  assert.ok(!html.includes('<script>') && !html.includes('<img'));
  assert.match(html, /<em>&lt;script&gt;/);
});

test('a link whose URL contains underscores or stars keeps the URL intact', () => {
  const html = renderMarkdown('See [docs](https://example.com/_static_/a_b_.html) and [more](https://example.com/*x*/y).');
  assert.match(html, /<a href="https:\/\/example\.com\/_static_\/a_b_\.html"[^>]*>docs<\/a>/);
  assert.match(html, /<a href="https:\/\/example\.com\/\*x\*\/y"[^>]*>more<\/a>/);
  assert.ok(!/<a href="[^"]*<em>/.test(html), 'no markup inside an href');
});

test('emphasis inside link text still works', () => {
  assert.match(renderMarkdown('[the *real* docs](https://example.com)'), /<a href="https:\/\/example\.com"[^>]*>the <em>real<\/em> docs<\/a>/);
});
