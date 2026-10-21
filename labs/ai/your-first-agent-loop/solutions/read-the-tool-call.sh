printf 'import json\ncall = json.load(open('\''reply.json'\''))\nprint(call['\''name'\''])\nprint(call['\''arguments'\'']['\''path'\''])\n' > read_call.py
