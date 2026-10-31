printf '%s\n' 'import json' '' 'cfg = json.load(open("configs/app.json"))' 'print("%s: %d default settings" % (cfg["app"], len(cfg["defaults"])))' > read_config.py
