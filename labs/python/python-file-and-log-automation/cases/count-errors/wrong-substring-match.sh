printf 'n = 0\nfor line in open('\''logs/app.log'\''):\n    if '\''ERROR'\'' in line:\n        n += 1\nprint(n)\n' > count_errors.py
