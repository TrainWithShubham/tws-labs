printf 'n = 0\nfor line in open('\''logs/app.log'\''):\n    if line.split()[2] == '\''WARN'\'':\n        n += 1\nprint(n)\n' > count_errors.py
