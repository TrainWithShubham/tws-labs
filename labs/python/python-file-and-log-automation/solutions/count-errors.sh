printf 'errors = 0\nfor line in open('\''logs/app.log'\''):\n    parts = line.split()\n    if len(parts) > 2 and parts[2] == '\''ERROR'\'':\n        errors += 1\nprint(errors)\n' > count_errors.py
