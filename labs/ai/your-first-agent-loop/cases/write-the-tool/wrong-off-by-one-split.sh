printf 'import sys\nprint(len(open(sys.argv[1]).read().split('\''\\n'\'')))\n' > tool.py
