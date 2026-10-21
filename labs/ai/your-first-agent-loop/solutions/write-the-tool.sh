printf 'import sys\nprint(len(open(sys.argv[1]).read().splitlines()))\n' > tool.py
