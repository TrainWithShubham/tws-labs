#!/bin/bash
# Starting state if you skipped ahead. Safe to run again: it only fills in what is missing.
[ -f total.txt ] || echo $((2 ** (32 - $(cut -d/ -f2 block.txt)))) > total.txt
