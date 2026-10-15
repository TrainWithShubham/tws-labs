const MAX_JSON_BODY_BYTES = 4 * 1024;

function send(res, status, type, body, extra = {}) {
  res.writeHead(status, { 'Content-Type': type, ...extra });
  res.end(body);
}
const json = (res, status, obj, extra) => send(res, status, 'application/json', JSON.stringify(obj), extra);

function readJson(req, res, cb) {
  let body = '';
  let tooBig = false;
  req.on('data', (c) => {
    if (tooBig) return;
    body += c;
    // Answer, then close the connection (rather than destroying it mid-response) and stop buffering.
    if (body.length > MAX_JSON_BODY_BYTES) { tooBig = true; json(res, 413, { error: 'too large', pass: false }, { Connection: 'close' }); }
  });
  req.on('end', () => {
    if (tooBig) return;
    let parsed;
    try { parsed = JSON.parse(body); } catch { return json(res, 400, { error: 'bad json' }); }
    cb(parsed || {});
  });
}

module.exports = { send, json, readJson, MAX_JSON_BODY_BYTES };
