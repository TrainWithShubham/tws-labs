printf '%s\n' 'import json' 'import sys' '' 'cfg = json.load(open(sys.argv[1]))' 'print("%s: %d default settings" % (cfg["app"], len(cfg)))' > read_config.py
