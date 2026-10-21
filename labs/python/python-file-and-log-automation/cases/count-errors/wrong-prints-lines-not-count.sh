printf 'for line in open('\''logs/app.log'\''):\n    if line.split()[2] == '\''ERROR'\'':\n        print(line.rstrip())\n' > count_errors.py
