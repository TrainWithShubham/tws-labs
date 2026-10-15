#!/bin/bash
# Starting state if you skipped ahead. Safe to run again: it only fills in what is missing.
mkdir -p app
grep -qi '^FROM' app/Dockerfile 2>/dev/null || printf 'FROM node:22-alpine\n' > app/Dockerfile
