# A scripted stand-in for a language model, for the "Your first agent loop" lab. It is NOT a model: it answers the same way every time,
# so a learner's agent can be graded fairly, and it needs no GPU, network or key.
#   python3 stand_in.py PORT [normal|flaky|endless]
# POST /chat  {"messages":[{"role":"user"|"tool", "content":"...", "id":"..."}]}
#   -> {"type":"text","text":"..."}  or  {"type":"tool_call","id":"call_N","name":"count_lines","arguments":{"path":"..."}}
# GET  /stats -> {"requests":N}
# The conversation arrives whole with every request (the stand-in keeps no memory), exactly like a real chat API.
import json
import re
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 0
MODE = sys.argv[2] if len(sys.argv) > 2 else 'normal'
if PORT < 1024 or MODE not in ('normal', 'flaky', 'endless'):
    sys.exit('usage: python3 stand_in.py PORT [normal|flaky|endless]')
requests = 0


def call(n, path, bad):
    return {'type': 'tool_call', 'id': 'call_%d' % n, 'name': 'count_lines', 'arguments': ('{path: %s' % path) if bad else {'path': path}}


def reply(messages):
    first = next((m for m in messages if m.get('role') == 'user'), None)
    results = [m for m in messages if m.get('role') == 'tool']
    text = first.get('content') if first and isinstance(first.get('content'), str) else ''
    files = re.findall(r'[\w./-]+\.(?:txt|log|md)\b', text)
    if not files:
        return {'type': 'text', 'text': 'Ask me how many lines are in a file, for example: how many lines are in notes.txt?'}
    good = [r for r in results if not str(r.get('content')).lower().startswith('error')]
    failures = len(results) - len(good)
    if MODE == 'endless':
        return call(len(results) + 1, files[0], False)
    if len(good) >= len(files):
        counts = ['%s: %s' % (f, str(good[i].get('content')).strip()) for i, f in enumerate(files)]
        total = sum(int(c) for c in (str(r.get('content')).strip() for r in good) if c.isdigit())
        return {'type': 'text', 'text': '%s. Total: %d lines.' % (', '.join(counts), total)}
    malformed = MODE == 'flaky' and failures == 0   # the first call of a flaky run is garbled; an error message sent back fixes it
    return call(len(good) + 1 + failures, files[len(good)], malformed)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def send(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == '/stats':
            return self.send(200, {'requests': requests})
        self.send(404, {'error': 'POST /chat with {"messages": [...]}'})

    def do_POST(self):
        global requests
        if self.path != '/chat':
            return self.send(404, {'error': 'POST /chat with {"messages": [...]}'})
        try:
            size = min(int(self.headers.get('Content-Length', 0)), 100000)
            body = json.loads(self.rfile.read(size) or b'null')
        except ValueError:
            return self.send(400, {'error': 'the body must be JSON'})
        if not isinstance(body, dict) or not isinstance(body.get('messages'), list) or not body['messages']:
            return self.send(400, {'error': 'send {"messages": [{"role": "user", "content": "..."}]}'})
        requests += 1
        self.send(200, reply([m for m in body['messages'] if isinstance(m, dict)]))


HTTPServer(('127.0.0.1', PORT), Handler).serve_forever()
