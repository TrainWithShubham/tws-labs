#!/bin/bash
# Starting state if you skipped ahead. Safe to run again: it only fills in what is missing.
# cwd: proj
cd proj
# revert needs a clean tree: drop the scribble and unstage the draft (the files stay)
git restore notes.txt 2>/dev/null || true
git restore --staged draft.txt 2>/dev/null || true
