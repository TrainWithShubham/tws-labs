// A deliberately tiny markdown renderer for lab text. Everything is HTML-escaped
// FIRST, so community-contributed lab content can never inject markup or script.
// Supported: paragraphs, - bullet lists, 1. numbered lists, ``` fences,
// `inline code`, **bold**, *italic* and _italic_, [text](http(s)://link).
const { esc } = require('./ui');

function inline(src) {
  const codes = [];
  let t = esc(src).replace(/`([^`]+)`/g, (_, c) => { codes.push(c); return '\u0001' + (codes.length - 1) + '\u0001'; });
  // Link targets are set aside first, like code: an underscore or star pair inside a URL is part of the URL, not emphasis.
  const urls = [];
  t = t.replace(/\]\((https?:\/\/[^)\s]+)\)/g, (_, u) => { urls.push(u); return ']\u0002' + (urls.length - 1) + '\u0002'; });
  t = t.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  // Emphasis only where it clearly is emphasis: a star pair hugging the text, not touching word characters, so globs (*.log),
  // arithmetic (2 * 3) and snake_case stay literal.
  t = t.replace(/(^|[^*\w])\*(?=\S)([^*\n]*?\S)\*(?![*\w])/g, '$1<em>$2</em>');
  t = t.replace(/(^|[^_\w])_(?=\S)([^_\n]*?\S)_(?![_\w])/g, '$1<em>$2</em>');
  t = t.replace(/\[([^\]]+)\]\u0002(\d+)\u0002/g, (_, text, i) => '<a href="' + urls[i] + '" target="_blank" rel="noopener noreferrer">' + text + '</a>');
  t = t.replace(/\u0002(\d+)\u0002/g, (_, i) => urls[i]);   // a stray marker (no matching [text]) goes back to plain text
  return t.replace(/\u0001(\d+)\u0001/g, (_, i) => '<code>' + codes[i] + '</code>');
}

function renderMarkdown(text) {
  const lines = String(text || '').replace(/[\u0000-\u0002]/g, '').replace(/\r\n?/g, '\n').split('\n');
  const out = [];
  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    if (/^```/.test(line)) {
      const buf = [];
      i++;
      while (i < lines.length && !/^```/.test(lines[i])) buf.push(lines[i++]);
      i++;
      out.push('<pre><code>' + esc(buf.join('\n')) + '</code></pre>');
    } else if (/^\s*[-*] /.test(line) || /^\s*\d+\. /.test(line)) {
      const tag = /^\s*\d+\. /.test(line) ? 'ol' : 'ul';
      const items = [];
      while (i < lines.length && /^\s*([-*]|\d+\.) /.test(lines[i])) items.push(inline(lines[i++].replace(/^\s*([-*]|\d+\.) /, '')));
      out.push(`<${tag}>` + items.map((x) => `<li>${x}</li>`).join('') + `</${tag}>`);
    } else if (!line.trim()) {
      i++;
    } else {
      const buf = [];
      while (i < lines.length && lines[i].trim() && !/^```/.test(lines[i]) && !/^\s*([-*]|\d+\.) /.test(lines[i])) buf.push(lines[i++]);
      out.push('<p>' + inline(buf.join(' ')) + '</p>');
    }
  }
  return out.join('\n');
}

module.exports = { renderMarkdown, esc };
