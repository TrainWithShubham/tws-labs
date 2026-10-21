printf 'lines = open('\''logs/app.log'\'').read().splitlines()\nprint(len([l for l in lines if l.split()[2] == '\''ERROR'\'']))\n' > count_errors.py
