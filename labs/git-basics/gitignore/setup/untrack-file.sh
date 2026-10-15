#!/bin/bash
# Starting state if you skipped ahead. Safe to run again: it only fills in what is missing.
# cwd: proj
cd proj
touch .gitignore
for r in '*.log' '.env' 'tmp/'; do grep -qxF "$r" .gitignore || echo "$r" >> .gitignore; done
git add .gitignore
git commit -q -m "Ignore rules" 2>/dev/null || true
