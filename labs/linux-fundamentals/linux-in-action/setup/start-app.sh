#!/bin/bash
# Starting state if you skipped ahead. Safe to run again: it only fills in what is missing.
mkdir -p logs
[ -f config.env ] || cp config.sample config.env
