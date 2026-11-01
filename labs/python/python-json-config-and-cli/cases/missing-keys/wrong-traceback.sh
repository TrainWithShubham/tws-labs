printf '%s\n' 'import json' 'import sys' '' 'cfg = json.load(open(sys.argv[1]))' 'cfg["app"]' 'cfg["defaults"]' 'print("ok")' > validate_config.py
