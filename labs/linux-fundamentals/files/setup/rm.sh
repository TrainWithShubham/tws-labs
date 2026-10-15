#!/bin/bash
# Starting state if you skipped ahead. Safe to run again: it only fills in what is missing.
mkdir -p workspace
[ -s workspace/archive.txt ] || echo "hello linux" > workspace/archive.txt
[ -e workspace/hello.txt ] || echo "hello linux" > workspace/hello.txt
