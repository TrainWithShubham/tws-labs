printf 'import sys\nwith open(sys.argv[1]) as f:\n    print(sum(1 for _ in f))\n' > tool.py
