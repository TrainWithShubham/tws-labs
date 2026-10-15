#!/bin/bash
# Starting state if you skipped ahead. Safe to run again: it only fills in what is missing.
mkdir -p workspace
[ -s workspace/hello.txt ] || echo "hello linux" > workspace/hello.txt
[ -e workspace/backup.txt ] || [ -e workspace/archive.txt ] || cp workspace/hello.txt workspace/backup.txt
