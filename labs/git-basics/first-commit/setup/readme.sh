#!/bin/bash
# Starting state if you skipped ahead. Safe to run again: it only fills in what is missing.
# cwd: myrepo
[ -d myrepo/.git ] || git init -q myrepo
