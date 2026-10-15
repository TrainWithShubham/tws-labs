#!/bin/bash
# Starting state if you skipped ahead. Safe to run again: it only fills in what is missing.
# cwd: proj
cd proj
if ! git rev-parse --verify -q feature > /dev/null; then
  git switch -q -c feature
  echo "new feature" > feature.txt
  git add feature.txt
  git commit -q -m "Add feature"
fi
git switch -q main
