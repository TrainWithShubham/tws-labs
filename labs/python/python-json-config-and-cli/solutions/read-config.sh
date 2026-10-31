printf '%s\n' 'import json' 'import sys' '' 'with open(sys.argv[1]) as f:' '    cfg = json.load(f)' 'print("%s: %d default settings" % (cfg["app"], len(cfg["defaults"])))' > read_config.py
