printf 'with open('\''logs/app.log'\'') as f:\n    total = sum(1 for line in f if line.split()[2] == '\''ERROR'\'')\nprint(f'\''{total}'\'')\n' > count_errors.py
