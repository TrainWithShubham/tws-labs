#!/bin/bash
# Starting state if you skipped ahead. Safe to run again: it only fills in what is missing.
# cwd: proj
cd proj
if [ -z "$(git stash list)" ]; then
  git stash -q
fi

