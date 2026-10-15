#!/bin/bash
# Starting state if you skipped ahead. Safe to run again: it only fills in what is missing.
# cwd: proj
cd proj
git rev-parse --verify -q feature > /dev/null || git switch -q -c feature
git switch -q feature
