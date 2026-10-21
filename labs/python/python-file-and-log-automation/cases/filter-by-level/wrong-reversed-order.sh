printf 'import sys\nfor line in reversed(open('\''logs/app.log'\'').readlines()):\n    if line.split()[2] == sys.argv[1]:\n        print(line.rstrip())\n' > filter_logs.py
