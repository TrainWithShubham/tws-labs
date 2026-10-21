printf 'import json\nc = json.load(open('\''reply.json'\''))\nprint(c['\''arguments'\'']['\''path'\''])\nprint(c['\''name'\''])\n' > read_call.py
