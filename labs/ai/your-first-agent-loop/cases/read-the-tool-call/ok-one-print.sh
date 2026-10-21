printf 'import json\nwith open('\''reply.json'\'') as f:\n    call = json.load(f)\nprint(call['\''name'\''], call['\''arguments'\'']['\''path'\''], sep='\''\\n'\'')\n' > read_call.py
