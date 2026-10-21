printf 'import sys\nprint(sum(1 for l in open('\''logs/app.log'\'') if l.split()[2] == sys.argv[1]))\n' > filter_logs.py
