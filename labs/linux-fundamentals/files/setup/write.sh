#!/bin/bash
# Starting state if you skipped ahead. Safe to run again: it only fills in what is missing.
mkdir -p workspace
[ -e workspace/hello.txt ] || touch workspace/hello.txt
