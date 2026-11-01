printf '%s\n' 'import sys' '' 'env = "dev"' 'if "--env" in sys.argv:' '    env = sys.argv[sys.argv.index("--env") + 1]' 'print("file=%s env=%s" % (sys.argv[1], env))' > config_cli.py
