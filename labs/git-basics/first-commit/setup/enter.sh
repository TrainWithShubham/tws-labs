#!/bin/bash
# Starting state if you skipped ahead. Safe to run again: it only fills in what is missing.
[ -d myrepo/.git ] || git init -q myrepo
