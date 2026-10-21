const test = require('node:test');
const assert = require('node:assert/strict');
const WebSocket = require('ws');
const { pipeWithBackpressure } = require('../../src/terminal');

// A shell and a socket that record what the server does with them. Sends complete only when the test says the browser has caught up.
function fakes() {
  const sends = [];
  const ws = { readyState: WebSocket.OPEN, send: (data, cb) => sends.push({ size: Buffer.byteLength(data), cb }) };
  let onData;
  const shell = { paused: 0, resumed: 0, onData: (fn) => { onData = fn; }, pause() { this.paused += 1; }, resume() { this.resumed += 1; } };
  return { ws, shell, sends, emit: (d) => onData(d) };
}

test('a client that never reads makes the server stop reading the pty after the high-water mark', () => {
  const { ws, shell, emit } = fakes();
  pipeWithBackpressure(shell, ws, { high: 100, low: 20 });
  emit('x'.repeat(60));
  assert.equal(shell.paused, 0);
  emit('x'.repeat(60));
  assert.equal(shell.paused, 1, 'over 100 bytes unsent: pause');
  emit('x'.repeat(60));
  assert.equal(shell.paused, 1, 'pausing twice is not needed');
});

test('output resumes once the browser has caught up to the low-water mark', () => {
  const { ws, shell, sends, emit } = fakes();
  pipeWithBackpressure(shell, ws, { high: 100, low: 20 });
  emit('x'.repeat(60));
  emit('x'.repeat(60));
  sends[0].cb();                      // 60 bytes still pending: above low
  assert.equal(shell.resumed, 0);
  sends[1].cb();                      // nothing pending
  assert.equal(shell.resumed, 1);
});

test('a closed socket drops output instead of queueing it', () => {
  const { ws, shell, sends, emit } = fakes();
  ws.readyState = WebSocket.CLOSED;
  pipeWithBackpressure(shell, ws, { high: 10, low: 2 });
  emit('x'.repeat(50));
  assert.equal(sends.length, 0);
  assert.equal(shell.paused, 0);
});
