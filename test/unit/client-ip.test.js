const test = require('node:test');
const assert = require('node:assert/strict');
const { clientIp } = require('../../src/lib');

test('uses the rightmost X-Forwarded-For entry (the one the ALB appended), not a client-forged one', () => {
  assert.equal(clientIp({ headers: { 'x-forwarded-for': '6.6.6.6, 203.0.113.9' }, socket: {} }), '203.0.113.9');
});

test('falls back to the socket peer when there is no X-Forwarded-For', () => {
  assert.equal(clientIp({ headers: {}, socket: { remoteAddress: '127.0.0.1' } }), '127.0.0.1');
});

test('ignores malformed X-Forwarded-For values and falls back to socket peer', () => {
  assert.equal(clientIp({ headers: { 'x-forwarded-for': 'malicious-string; rm -rf /' }, socket: { remoteAddress: '10.0.0.1' } }), '10.0.0.1');
  assert.equal(clientIp({ headers: { 'x-forwarded-for': '1.2.3.4, not-an-ip' }, socket: { remoteAddress: '10.0.0.1' } }), '10.0.0.1');
});

test('trustProxy: false ignores X-Forwarded-For entirely', () => {
  assert.equal(clientIp({ headers: { 'x-forwarded-for': '203.0.113.9' }, socket: { remoteAddress: '127.0.0.1' } }, { trustProxy: false }), '127.0.0.1');
});
