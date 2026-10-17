#!/bin/bash
# Starting state if you skipped ahead. Safe to run again: it only fills in what is missing.
# cwd: proj
cd proj
if [ -z "$(git stash list)" ]; then
  git switch -q feature
  echo "print('uncommitted work in progress')" >> app.py
  git stash -q
fi
if [ "$(git branch --show-current)" != "main" ]; then
  git switch -q main
fi
if [ ! -f hotfix.txt ]; then
  echo "critical fix" > hotfix.txt
  git add hotfix.txt
  git commit -q -m "Apply hotfix"
fi

