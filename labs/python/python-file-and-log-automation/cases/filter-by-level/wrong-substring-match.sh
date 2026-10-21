printf 'import sys\nfor line in open('\''logs/app.log'\''):\n    if sys.argv[1] in line:\n        print(line.rstrip())\n' > filter_logs.py
